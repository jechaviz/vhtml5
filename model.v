module vhtml5

pub enum NodeKind {
	document
	doctype
	element
	text
	comment
}

pub struct Attribute {
pub:
	name string
	value string
}

pub struct Node {
pub:
	kind NodeKind
	tag string
	text string
	attrs []Attribute
	children []Node
	self_closing bool
}

pub struct Document {
pub:
	doctype string
	children []Node
	warnings []string
}

pub struct CompileOptions {
pub:
	source_name string
}

pub struct CompiledDocument {
pub:
	source_name string
	document Document
}

pub struct VEmitOptions {
pub:
	module_name string = 'compiled_html'
	function_name string = 'load_document'
	include_header bool = true
}

pub fn (doc Document) node_count() int {
	mut total := 0
	for child in doc.children {
		total += child.node_count()
	}
	return total
}

pub fn (node Node) node_count() int {
	mut total := 1
	for child in node.children {
		total += child.node_count()
	}
	return total
}

pub fn element(tag string, attrs []Attribute, children []Node) Node {
	return Node{kind: .element, tag: tag.to_lower(), attrs: attrs.clone(), children: children.clone()}
}

pub fn text(value string) Node {
	return Node{kind: .text, text: value}
}

pub fn comment(value string) Node {
	return Node{kind: .comment, text: value}
}

pub fn (doc Document) title() string {
	for child in doc.children {
		value := child.find_first_text('title')
		if value != '' {
			return value
		}
	}
	return ''
}

pub fn (doc Document) text_content() string {
	mut parts := []string{}
	for child in doc.children {
		value := child.text_content()
		if value != '' {
			parts << value
		}
	}
	return collapse_spaces(parts.join(' '))
}

pub fn (node Node) attr(name string) ?string {
	needle := name.to_lower()
	for attr in node.attrs {
		if attr.name == needle {
			return attr.value
		}
	}
	return none
}

pub fn (node Node) find_first(tag string) ?Node {
	needle := tag.to_lower()
	if node.kind == .element && node.tag == needle {
		return node
	}
	for child in node.children {
		found := child.find_first(needle) or { continue }
		return found
	}
	return none
}

pub fn (node Node) find_first_text(tag string) string {
	found := node.find_first(tag) or { return '' }
	return found.text_content()
}

pub fn (node Node) text_content() string {
	if node.kind == .text {
		return collapse_spaces(node.text)
	}
	if node.kind == .comment || node.kind == .doctype {
		return ''
	}
	mut parts := []string{}
	for child in node.children {
		value := child.text_content()
		if value != '' {
			parts << value
		}
	}
	return collapse_spaces(parts.join(' '))
}

pub fn collapse_spaces(input string) string {
	mut out := []u8{cap: input.len}
	mut last_space := true
	for i := 0; i < input.len; i++ {
		ch := input[i]
		if ch <= ` ` {
			if !last_space {
				out << ` `
			}
			last_space = true
			continue
		}
		out << ch
		last_space = false
	}
	return out.bytestr().trim_space()
}
