import { z } from "zod";
import { defineTool } from "./types";

const Citation = z.object({
  title: z.string(),
  url: z.string().url(),
  source: z.string(),
  publishedAt: z.string().optional(),
  journal: z.string().optional(),
  authors: z.array(z.string()).default([]),
  snippet: z.string().optional(),
});

const Output = z.object({
  query: z.string(),
  searchedAt: z.string(),
  sources: z.array(Citation),
});

type CitationResult = z.infer<typeof Citation>;

interface PubMedSearchResponse {
  esearchresult?: {
    idlist?: string[];
  };
}

interface PubMedSummaryResponse {
  result?: Record<string, unknown> & {
    uids?: string[];
  };
}

interface EuropePmcResponse {
  resultList?: {
    result?: Array<{
      title?: string;
      journalTitle?: string;
      firstPublicationDate?: string;
      authorString?: string;
      abstractText?: string;
      doi?: string;
      pmid?: string;
      source?: string;
    }>;
  };
}

export const researchScienceTool = defineTool({
  name: "research_science",
  description:
    "Search biomedical/scientific literature for evidence-grounded answers. " +
    "Returns clickable citations from PubMed and Europe PMC. Use this when " +
    "the user asks for scientific evidence, mechanisms, protocols, or sources.",
  input: z
    .object({
      query: z.string().min(3).describe("The scientific question or search query."),
      maxResults: z.number().int().min(1).max(8).default(5),
    })
    .strict(),
  output: Output,
  parameters: {
    type: "object",
    properties: {
      query: {
        type: "string",
        description: "Scientific question or search query.",
      },
      maxResults: {
        type: "number",
        description: "Maximum citations to return, between 1 and 8.",
        minimum: 1,
        maximum: 8,
      },
    },
    required: ["query"],
    additionalProperties: false,
  },
  async run(args) {
    const maxResults = args.maxResults ?? 5;
    const [pubmed, europePmc] = await Promise.all([
      searchPubMed(args.query, Math.ceil(maxResults / 2)),
      searchEuropePmc(args.query, maxResults),
    ]);

    const deduped = dedupeSources([...pubmed, ...europePmc]).slice(0, maxResults);
    return {
      query: args.query,
      searchedAt: new Date().toISOString(),
      sources: deduped,
    };
  },
});

async function searchPubMed(query: string, maxResults: number): Promise<CitationResult[]> {
  try {
    const searchURL = new URL("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi");
    searchURL.search = new URLSearchParams({
      db: "pubmed",
      retmode: "json",
      retmax: String(maxResults),
      term: query,
    }).toString();

    const searchResponse = await fetch(searchURL.toString());
    if (!searchResponse.ok) return [];
    const search = (await searchResponse.json()) as PubMedSearchResponse;
    const ids = search.esearchresult?.idlist ?? [];
    if (ids.length === 0) return [];

    const summaryURL = new URL("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi");
    summaryURL.search = new URLSearchParams({
      db: "pubmed",
      retmode: "json",
      id: ids.join(","),
    }).toString();

    const summaryResponse = await fetch(summaryURL.toString());
    if (!summaryResponse.ok) return [];
    const summary = (await summaryResponse.json()) as PubMedSummaryResponse;
    const result = summary.result ?? {};

    return ids.flatMap((id) => {
      const row = result[id] as Record<string, unknown> | undefined;
      if (!row) return [];
      const title = stringValue(row.title).replace(/\.$/, "");
      if (!title) return [];
      const authorsRaw = Array.isArray(row.authors) ? row.authors : [];
      const authors = authorsRaw
        .map((author) => (typeof author === "object" && author ? stringValue((author as Record<string, unknown>).name) : ""))
        .filter(Boolean)
        .slice(0, 4);
      return [{
        title,
        source: "PubMed",
        url: `https://pubmed.ncbi.nlm.nih.gov/${id}/`,
        publishedAt: stringValue(row.pubdate) || undefined,
        journal: stringValue(row.fulljournalname) || stringValue(row.source) || undefined,
        authors,
      }];
    });
  } catch {
    return [];
  }
}

async function searchEuropePmc(query: string, maxResults: number): Promise<CitationResult[]> {
  try {
    const url = new URL("https://www.ebi.ac.uk/europepmc/webservices/rest/search");
    url.search = new URLSearchParams({
      query,
      format: "json",
      pageSize: String(maxResults),
      sort: "CITED desc",
    }).toString();
    const response = await fetch(url.toString());
    if (!response.ok) return [];
    const payload = (await response.json()) as EuropePmcResponse;
    const results = payload.resultList?.result ?? [];
    return results.flatMap((row) => {
      const title = (row.title ?? "").replace(/\.$/, "");
      if (!title) return [];
      const url = row.doi
        ? `https://doi.org/${row.doi}`
        : row.pmid
          ? `https://pubmed.ncbi.nlm.nih.gov/${row.pmid}/`
          : undefined;
      if (!url) return [];
      return [{
        title,
        source: row.source ? `Europe PMC · ${row.source}` : "Europe PMC",
        url,
        publishedAt: row.firstPublicationDate,
        journal: row.journalTitle,
        authors: splitAuthors(row.authorString),
        snippet: stripTags(row.abstractText).slice(0, 220) || undefined,
      }];
    });
  } catch {
    return [];
  }
}

function dedupeSources(sources: CitationResult[]): CitationResult[] {
  const seen = new Set<string>();
  const out: CitationResult[] = [];
  for (const source of sources) {
    const key = source.url.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(source);
  }
  return out;
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function splitAuthors(authorString?: string): string[] {
  if (!authorString) return [];
  return authorString
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
    .slice(0, 4);
}

function stripTags(value?: string): string {
  if (!value) return "";
  return value.replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim();
}
