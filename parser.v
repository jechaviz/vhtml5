module vhtml5

struct ParseResult {
	nodes []Node
	index int
}

struct HtmlParser {
	tokens []Token
mut:
	warnings []string
	doctype string
}

pub fn parse_document(source string) !Document {
	mut parser := HtmlParser{tokens: tokenize(source)}
	result := parser.parse_children(0, '')
	return Document{doctype: parser.doctype, children: result.nodes, warnings: parser.warnings}
}

pub fn compile(source string, options CompileOptions) !CompiledDocument {
	return CompiledDocument{source_name: options.source_name, document: parse_document(source)!}
}

fn (mut parser HtmlParser) parse_children(start int, until string) ParseResult {
	mut nodes := []Node{}
	mut index := start
	mut closed := false
	for index < parser.tokens.len {
		token := parser.tokens[index]
		match token.kind {
			.doctype {
				parser.doctype = token.text
				index++
			}
			.comment {
				nodes << Node{kind: .comment, text: token.text}
				index++
			}
			.text {
				nodes << Node{kind: .text, text: token.text}
				index++
			}
			.end_tag {
				index++
				if until == '' {
					parser.warn('unexpected closing tag </${token.tag}>')
					continue
				}
				if token.tag == until {
					closed = true
					break
				}
				parser.warn('expected </${until}> but found </${token.tag}>')
				break
			}
			.start_tag {
				index++
				if token.self_closing {
					nodes << Node{kind: .element, tag: token.tag, attrs: token.attrs, self_closing: true}
					continue
				}
				nested := parser.parse_children(index, token.tag)
				index = nested.index
				nodes << Node{kind: .element, tag: token.tag, attrs: token.attrs, children: nested.nodes}
			}
		}
	}
	if until != '' && !closed {
		parser.warn('missing closing tag </${until}>')
	}
	return ParseResult{nodes: nodes, index: index}
}

fn (mut parser HtmlParser) warn(message string) {
	parser.warnings << message
}
