import XCTest
@testable import MarkmeCore

final class FeaturePageTests: XCTestCase {
    private let spec = """
    # Viewer

    ## Intent

    A small reader for the Mac. The formatted page is already there.

    The second paragraph stays in the spec, below the map.

    ## Goals

    - Open on the formatted page.
    - Stay read only.

    ## Non-goals for 1.0

    - Editing the file.
    - A project panel.

    ## How it is built

    See [the goals](#goals).

    ![window](shot.png)

    The notes are in [other](notes/other.md).
    """

    private let plan = """
    # Viewer Implementation Plan

    **Spec:** `docs/superpowers/specs/design.md`

    ## Global Constraints

    - Read only.

    ### Task 1: Parse everyday markdown

    **Files:**
    - Create: `Sources/Page.swift`

    ### Task 2: Strip active HTML

    Keep the page inert.
    """

    func testANoteWithoutASpecCitationStaysASingleFile() throws {
        let directory = try makeDirectory()
        defer { remove(directory) }
        let cited = FeaturePage.load(plan: "# Notes\n\nHello.\n", planDirectory: directory)
        XCTAssertNil(cited)
    }

    func testACitationInsideAFenceOrAfterTheFirstSectionIsIgnored() throws {
        let directory = try makeDirectory()
        defer { remove(directory) }
        let fenced = """
        # Plan

        ```
        **Spec:** `docs/design.md`
        ```

        ## Later

        **Spec:** `docs/design.md`
        """
        try write("hello", to: directory.appendingPathComponent("docs/design.md"))
        XCTAssertNil(FeaturePage.load(plan: fenced, planDirectory: directory))
    }

    func testASpecBesideThePlanAndARepoRelativeSpecBothResolve() throws {
        let root = try makeDirectory()
        defer { remove(root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let beside = root.appendingPathComponent("design.md")
        try spec.write(to: beside, atomically: true, encoding: .utf8)
        let local = FeaturePage.load(
            plan: "**Spec:** `design.md`\n\n## Work\n",
            planDirectory: root
        )
        XCTAssertEqual(local?.url.standardizedFileURL.path, beside.standardizedFileURL.path)

        let specs = root.appendingPathComponent("docs/superpowers/specs")
        try FileManager.default.createDirectory(at: specs, withIntermediateDirectories: true)
        let design = specs.appendingPathComponent("design.md")
        try spec.write(to: design, atomically: true, encoding: .utf8)
        let plans = root.appendingPathComponent("docs/superpowers/plans")
        let cited = FeaturePage.load(plan: plan, planDirectory: plans)
        XCTAssertEqual(cited?.label, "docs/superpowers/specs/design.md")
        XCTAssertEqual(cited?.url.standardizedFileURL.path, design.standardizedFileURL.path)
    }

    func testAMissingSpecLeavesThePlanAlone() throws {
        let root = try makeDirectory()
        defer { remove(root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let plans = root.appendingPathComponent("docs/superpowers/plans")
        XCTAssertNil(FeaturePage.load(plan: plan, planDirectory: plans))
    }

    func testThePageLeadsWithTheMapThenTheSpecThenThePlan() throws {
        let fixture = try fixture()
        defer { remove(fixture.root) }
        let page = composed(fixture)
        XCTAssertTrue(page.contains("docs/superpowers/specs/design.md · plan.md"), page)
        XCTAssertTrue(page.contains("A small reader for the Mac."), page)
        XCTAssertFalse(map(of: page).contains("The second paragraph stays in the spec"), page)
        XCTAssertTrue(page.contains("Open on the formatted page."), page)
        XCTAssertTrue(page.contains("Editing the file."), page)
        XCTAssertTrue(page.contains(">Goals<"), page)
        XCTAssertTrue(page.contains(">Out of scope<"), page)
        XCTAssertTrue(page.contains(">Tasks<"), page)
        let specHeading = try XCTUnwrap(page.range(of: "id=\"markme-feature-spec\""))
        let planHeading = try XCTUnwrap(page.range(of: "id=\"markme-feature-plan\""))
        let intent = try XCTUnwrap(page.range(of: "A small reader for the Mac."))
        XCTAssertLessThan(intent.lowerBound, specHeading.lowerBound)
        XCTAssertLessThan(specHeading.lowerBound, planHeading.lowerBound)
        XCTAssertTrue(page.contains("The second paragraph stays in the spec"), page)
        XCTAssertTrue(page.contains("Keep the page inert."), page)
    }

    func testPortugueseMapLabels() throws {
        let fixture = try fixture()
        defer { remove(fixture.root) }
        let page = composed(fixture, languageCode: "pt-BR")
        XCTAssertTrue(page.contains(">Objetivos<"), page)
        XCTAssertTrue(page.contains(">Fora<"), page)
        XCTAssertTrue(page.contains(">Tarefas<"), page)
        XCTAssertTrue(page.contains(">Plano<"), page)
    }

    func testATaskScrollsToThePlanHeadingOnThisPage() throws {
        let fixture = try fixture()
        defer { remove(fixture.root) }
        let page = composed(fixture)
        let planHTML = MarkdownRenderer.render(plan, baseDirectory: fixture.plans).htmlBody
        let taskID = try XCTUnwrap(headingID(matching: "Task 1: Parse everyday markdown", in: planHTML), planHTML)
        XCTAssertTrue(page.contains("<a href=\"#\(taskID)\">Parse everyday markdown</a>"), page)
        XCTAssertTrue(page.contains("id=\"\(taskID)\""), page)
        XCTAssertTrue(page.contains("<a href=\"#"), page)
        let second = try XCTUnwrap(headingID(matching: "Task 2: Strip active HTML", in: planHTML))
        XCTAssertTrue(page.contains("<a href=\"#\(second)\">Strip active HTML</a>"), page)
    }

    func testSpecMarkupDoesNotReusePlanSourcePositionsOrHeadingIds() throws {
        let fixture = try fixture()
        defer { remove(fixture.root) }
        let page = composed(fixture)
        let specStart = try XCTUnwrap(page.range(of: "id=\"markme-feature-spec\""))
        let planStart = try XCTUnwrap(page.range(of: "id=\"markme-feature-plan\""))
        let specHTML = String(page[specStart.lowerBound..<planStart.lowerBound])
        XCTAssertFalse(specHTML.contains("data-sourcepos"), specHTML)
        XCTAssertTrue(specHTML.contains("id=\"spec-goals\""), specHTML)
        XCTAssertTrue(specHTML.contains("href=\"#spec-goals\""), specHTML)
        XCTAssertTrue(specHTML.contains("src=\"../specs/shot.png\""), specHTML)
        XCTAssertTrue(specHTML.contains("href=\"../specs/notes/other.md\""), specHTML)
        let planHTML = String(page[planStart.lowerBound...])
        XCTAssertTrue(planHTML.contains("data-sourcepos"), planHTML)
        XCTAssertTrue(planHTML.contains("id=\"task-1-parse-everyday-markdown\""), planHTML)
        XCTAssertFalse(planHTML.contains("id=\"spec-task-1"), planHTML)
    }

    func testTheCheckedInMarkmePlanComposesItsSpec() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let planURL = root.appendingPathComponent("docs/superpowers/plans/2026-10-20-markme-viewer.md")
        let planText = try String(contentsOf: planURL, encoding: .utf8)
        let cited = try XCTUnwrap(FeaturePage.load(
            plan: planText,
            planDirectory: planURL.deletingLastPathComponent(),
            excluding: planURL
        ))
        let planHTML = MarkdownRenderer.render(planText, baseDirectory: planURL.deletingLastPathComponent()).htmlBody
        let page = FeaturePage.compose(
            plan: planText,
            planHTML: planHTML,
            spec: cited,
            planDirectory: planURL.deletingLastPathComponent(),
            planLabel: planURL.lastPathComponent,
            languageCode: "en"
        )
        XCTAssertTrue(page.contains("markme is a small Markdown viewer for the Mac."), page)
        XCTAssertTrue(page.contains("A double-click on a Markdown file in the Finder opens markme already on the formatted page."), page)
        XCTAssertTrue(page.contains("Editing or saving the file."), page)
        XCTAssertTrue(page.contains(">Parse everyday markdown</a>"), page)
        XCTAssertTrue(page.contains(">Default reader and live reload</a>"), page)
        XCTAssertTrue(page.contains("id=\"markme-feature-spec\""), page)
        XCTAssertLessThan(
            try XCTUnwrap(page.range(of: "id=\"markme-feature-spec\"")).lowerBound,
            try XCTUnwrap(page.range(of: "id=\"markme-feature-plan\"")).lowerBound
        )
    }

    private struct Fixture {
        var root: URL
        var plans: URL
        var spec: CitedSpec
    }

    private func fixture() throws -> Fixture {
        let root = try makeDirectory()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let specs = root.appendingPathComponent("docs/superpowers/specs")
        let plans = root.appendingPathComponent("docs/superpowers/plans")
        try FileManager.default.createDirectory(at: specs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: plans, withIntermediateDirectories: true)
        let design = specs.appendingPathComponent("design.md")
        try spec.write(to: design, atomically: true, encoding: .utf8)
        let cited = try XCTUnwrap(FeaturePage.load(plan: plan, planDirectory: plans))
        return Fixture(root: root, plans: plans, spec: cited)
    }

    private func composed(_ fixture: Fixture, languageCode: String = "en") -> String {
        let planHTML = MarkdownRenderer.render(plan, baseDirectory: fixture.plans, languageCode: languageCode).htmlBody
        return FeaturePage.compose(
            plan: plan,
            planHTML: planHTML,
            spec: fixture.spec,
            planDirectory: fixture.plans,
            planLabel: "plan.md",
            languageCode: languageCode
        )
    }

    private func map(of page: String) -> String {
        guard let start = page.range(of: "<section class=\"feature-map\">"),
              let end = page.range(of: "</section>", range: start.upperBound..<page.endIndex) else { return page }
        return String(page[start.lowerBound..<end.upperBound])
    }

    private func headingID(matching title: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"(?is)<h[1-6]\b([^>]*)>(.*?)</h[1-6]>"#) else { return nil }
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard match.numberOfRanges == 3,
                  let attrRange = Range(match.range(at: 1), in: html),
                  let innerRange = Range(match.range(at: 2), in: html) else { continue }
            let text = String(html[innerRange]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            guard text.contains(title) else { continue }
            let attributes = String(html[attrRange])
            guard let idStart = attributes.range(of: "id=\""),
                  let idEnd = attributes.range(of: "\"", range: idStart.upperBound..<attributes.endIndex) else { continue }
            return String(attributes[idStart.upperBound..<idEnd.lowerBound])
        }
        return nil
    }

    private func makeDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("markme-feature-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
