import { marked, Tokenizer } from "marked"

// marked dedents a list item before lexing it, so a table on unindented (lazy)
// lines reads like one indented under the item. GitHub keeps lazy pipe lines as
// paragraph text instead, so fold such a table back into the text before it.
marked.use({
  tokenizer: {
    list(src) {
      const list = Tokenizer.prototype.list.call(this, src)
      if (list) list.items.forEach((item) => foldLazyTables(item, this.lexer))
      return list
    }
  }
})

function foldLazyTables(item, lexer) {
  const rawLines = item.raw.split("\n")

  item.tokens = item.tokens.reduce((tokens, token) => {
    const previous = tokens.at(-1)
    // Lexed from dedented text, so the header line survives verbatim in the raw only when unindented.
    const lazy = token.type === "table" && rawLines.includes(token.raw.split("\n")[0])
    if (!lazy || !["text", "paragraph"].includes(previous?.type)) {
      tokens.push(token)
      return tokens
    }
    const tableText = token.raw.replace(/\n+$/, "")
    previous.raw = previous.raw.replace(/\n*$/, "\n") + token.raw
    previous.text = `${previous.text}\n${tableText}`
    previous.tokens = lexer.inline(previous.text)
    return tokens
  }, [])
}

export { marked }
