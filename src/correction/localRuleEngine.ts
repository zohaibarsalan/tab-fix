import type { CorrectionEngine, CorrectionRequest } from "./types";
import type { CorrectionResult } from "../shared/ipc";

type Rule = {
  label: string;
  apply: (text: string) => string;
};

const replacementRules: Rule[] = [
  {
    label: "Collapsed repeated whitespace",
    apply: (text) => text.replace(/[ \t]{2,}/g, " ")
  },
  {
    label: "Fixed space before punctuation",
    apply: (text) => text.replace(/\s+([,.;:!?])/g, "$1")
  },
  {
    label: "Added space after punctuation",
    apply: (text) => text.replace(/([,.;:!?])([A-Za-z])/g, "$1 $2")
  },
  {
    label: "Capitalized standalone I",
    apply: (text) => text.replace(/\bi\b/g, "I")
  },
  {
    label: "Fixed common contractions",
    apply: (text) =>
      text
        .replace(/\bdont\b/gi, "don't")
        .replace(/\bcant\b/gi, "can't")
        .replace(/\bwont\b/gi, "won't")
        .replace(/\bim\b/gi, "I'm")
        .replace(/\bive\b/gi, "I've")
        .replace(/\bid\b/gi, "I'd")
        .replace(/\bill\b/gi, "I'll")
        .replace(/\bthats\b/gi, "that's")
        .replace(/\btheres\b/gi, "there's")
        .replace(/\bisnt\b/gi, "isn't")
        .replace(/\barent\b/gi, "aren't")
  },
  {
    label: "Fixed common agreement errors",
    apply: (text) =>
      text
        .replace(/\bthis are\b/gi, "this is")
        .replace(/\bthat are\b/gi, "that is")
        .replace(/\bthese is\b/gi, "these are")
        .replace(/\bthose is\b/gi, "those are")
        .replace(/\byou is\b/gi, "you are")
        .replace(/\bwe was\b/gi, "we were")
        .replace(/\bthey was\b/gi, "they were")
        .replace(/\bI has\b/g, "I have")
  },
  {
    label: "Fixed article before vowel sound",
    apply: (text) => text.replace(/\ba ([aeiouAEIOU])/g, "an $1")
  }
];

function preserveOuterWhitespace(input: string, fixedCore: string): string {
  const leading = input.match(/^\s*/)?.[0] ?? "";
  const trailing = input.match(/\s*$/)?.[0] ?? "";

  return `${leading}${fixedCore}${trailing}`;
}

function capitalizeSentenceStarts(text: string): string {
  return text.replace(/(^|[.!?]\s+)([a-z])/g, (_match, prefix: string, letter: string) => {
    return `${prefix}${letter.toUpperCase()}`;
  });
}

function addTerminalPunctuation(text: string): string {
  if (text.length === 0 || /[.!?]$/.test(text)) {
    return text;
  }

  return `${text}.`;
}

export class LocalRuleEngine implements CorrectionEngine {
  async correct(request: CorrectionRequest): Promise<CorrectionResult> {
    const startedAt = performance.now();
    const fixes: string[] = [];
    const core = request.text.trim();
    let fixed = core;

    for (const rule of replacementRules) {
      const next = rule.apply(fixed);

      if (next !== fixed) {
        fixes.push(rule.label);
        fixed = next;
      }
    }

    const capitalized = capitalizeSentenceStarts(fixed);
    if (capitalized !== fixed) {
      fixes.push("Capitalized sentence starts");
      fixed = capitalized;
    }

    const punctuated = addTerminalPunctuation(fixed);
    if (punctuated !== fixed) {
      fixes.push("Added terminal punctuation");
      fixed = punctuated;
    }

    const output = preserveOuterWhitespace(request.text, fixed);

    return {
      input: request.text,
      output,
      changed: output !== request.text,
      fixes,
      durationMs: Math.round(performance.now() - startedAt)
    };
  }
}
