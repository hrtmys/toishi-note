// Unit tests for lib/text_format.js.
import { describe, it } from "node:test"
import assert from "node:assert/strict"
import {
  TEXT_FORMAT_ORDER,
  applyTextTransforms,
  collapseNewlines,
  fullwidthToHalfwidth,
  removeBracketed,
  removeNumberJpSpace,
  removePunctuationSpace
} from "../../app/javascript/lib/text_format.js"

describe("fullwidthToHalfwidth", () => {
  it("converts fullwidth digits to halfwidth digits", () => {
    assert.equal(fullwidthToHalfwidth("１２３４５６７８９０"), "1234567890")
  })

  it("leaves halfwidth text untouched", () => {
    assert.equal(fullwidthToHalfwidth("123 and テキスト"), "123 and テキスト")
  })
})

describe("removePunctuationSpace", () => {
  it("removes spaces after Japanese commas and periods", () => {
    assert.equal(removePunctuationSpace("こんにちは、 世界。 次へ"), "こんにちは、世界。次へ")
  })

  it("leaves other spacing untouched", () => {
    assert.equal(removePunctuationSpace("1000 と 文字"), "1000 と 文字")
  })
})

describe("removeNumberJpSpace", () => {
  it("removes spaces between a number and following Japanese text", () => {
    assert.equal(removeNumberJpSpace("1000 と 文字"), "1000と 文字")
  })

  it("leaves non-matching spacing untouched", () => {
    assert.equal(removeNumberJpSpace("文字 の間"), "文字 の間")
  })
})

describe("collapseNewlines", () => {
  it("collapses runs of blank lines into one", () => {
    assert.equal(collapseNewlines("行1\n\n\n行2"), "行1\n行2")
  })

  it("leaves single newlines untouched", () => {
    assert.equal(collapseNewlines("行1\n行2"), "行1\n行2")
  })
})

describe("removeBracketed", () => {
  it("removes text wrapped in square brackets", () => {
    assert.equal(removeBracketed("keep [削除したい] keep"), "keep  keep")
  })

  it("leaves unbracketed text untouched", () => {
    assert.equal(removeBracketed("no brackets here"), "no brackets here")
  })
})

describe("applyTextTransforms", () => {
  // Same content as the system test's note fixture, all options on.
  const input = "１２３４５６７８９０\n1000 と 文字 の間 の 空白\n行1\n\n\n行2\n[削除したい]\n"
  const allOptions = [
    "fullwidth_to_halfwidth",
    "punctuation_space",
    "number_jp_space",
    "remove_brackets",
    "collapse_newlines"
  ]

  it("applies every selected transformation in the fixed order", () => {
    const result = applyTextTransforms(input, allOptions)
    assert.match(result, /1234567890/)
    assert.doesNotMatch(result, /1000\s+と/)
    assert.doesNotMatch(result, /\n{2,}/)
    assert.doesNotMatch(result, /\[削除したい\]/)
    // NOTE: number_jp_space's \s+ also spans newlines, so "行1\n\n\n行2"
    // (digit before the blank lines, kanji after) joins into one line.
    // That quirk predates this extraction — locked in here as-is.
    assert.equal(result, "1234567890\n1000と 文字 の間 の 空白\n行1行2\n")
  })

  it("is deterministic regardless of the option order passed in", () => {
    const shuffled = [...allOptions].reverse()
    assert.equal(applyTextTransforms(input, shuffled), applyTextTransforms(input, allOptions))
  })

  it("applies only the selected transformations", () => {
    assert.equal(applyTextTransforms("１２３ [x]", ["fullwidth_to_halfwidth"]), "123 [x]")
  })

  it("ignores unknown option names", () => {
    assert.equal(applyTextTransforms("abc", ["not_a_real_option"]), "abc")
  })
})

describe("TEXT_FORMAT_ORDER", () => {
  it("lists the five Quick Formatting options, collapsing newlines last", () => {
    assert.deepEqual(TEXT_FORMAT_ORDER, [ "fullwidth_to_halfwidth", "punctuation_space", "number_jp_space", "remove_brackets", "collapse_newlines" ])
  })

  const samples = {
    fullwidth_to_halfwidth: "１２３",
    punctuation_space: "はい、 そうです。 次",
    number_jp_space: "3 個",
    remove_brackets: "本文[注]",
    collapse_newlines: "a\n\n\nb"
  }

  for (const key of TEXT_FORMAT_ORDER) {
    it(`${key} alone changes a sample holding its pattern`, () => {
      assert.notEqual(applyTextTransforms(samples[key], [ key ]), samples[key])
    })
  }
})
