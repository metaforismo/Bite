import { describe, it, expect, vi, afterEach } from "vitest";
import { researchScienceTool } from "../src/tools/researchScience";
import type { ToolContext } from "../src/tools/types";

describe("research_science tool", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("returns deduped clickable citations from PubMed and Europe PMC", async () => {
    vi.stubGlobal("fetch", async (input: RequestInfo | URL) => {
      const url = input.toString();
      if (url.includes("esearch.fcgi")) {
        return jsonResponse({ esearchresult: { idlist: ["12345"] } });
      }
      if (url.includes("esummary.fcgi")) {
        return jsonResponse({
          result: {
            uids: ["12345"],
            "12345": {
              title: "Protein timing and resistance training.",
              pubdate: "2025",
              fulljournalname: "Journal of Strength",
              authors: [{ name: "Rivera A" }],
            },
          },
        });
      }
      if (url.includes("europepmc")) {
        return jsonResponse({
          resultList: {
            result: [
              {
                title: "Sleep and muscle recovery.",
                journalTitle: "Sports Medicine",
                firstPublicationDate: "2024-03-01",
                authorString: "Chen L, Patel R",
                doi: "10.1000/sleep-recovery",
                source: "MED",
              },
            ],
          },
        });
      }
      return new Response("not found", { status: 404 });
    });

    const result = await researchScienceTool.run(
      { query: "protein timing resistance training", maxResults: 4 },
      {} as ToolContext
    );

    expect(result.sources).toHaveLength(2);
    expect(result.sources[0].url).toBe("https://pubmed.ncbi.nlm.nih.gov/12345/");
    expect(result.sources[1].url).toBe("https://doi.org/10.1000/sleep-recovery");
  });
});

function jsonResponse(value: unknown): Response {
  return new Response(JSON.stringify(value), {
    status: 200,
    headers: { "content-type": "application/json" },
  });
}
