module vhtml5

import strconv

enum TokenKind {
	doctype
	start_tag
	end_tag
	text
	comment
}

struct Token {
	kind TokenKind
	tag string
	text string
	attrs []Attribute
	self_closing bool
}

fn tokenize(source string) []Token {
	mut tokens := []Token{}
	mut i := 0
	for i < source.len {
		if source[i] != `<` {
			next := source.index_after('<', i) or { source.len }
			value := decode_entities(source[i..next])
			if value.trim_space() != '' {
				tokens << Token{kind: .text, text: value}
			}
			i = next
			continue
		}
		if source[i..].starts_with('<!--') {
			end := source.index_after('-->', i + 4) or { source.len - 3 }
			tokens << Token{kind: .comment, text: source[i + 4..end]}
			i = end + 3
			continue
		}
		end := source.index_after('>', i + 1) or {
			tokens << Token{kind: .text, text: decode_entities(source[i..])}
			break
		}
		raw := source[i + 1..end].trim_space()
		lower := raw.to_lower()
		if lower.starts_with('!doctype') {
			tokens << Token{kind: .doctype, text: raw[8..].trim_space()}
			i = end + 1
			continue
		}
		if raw.starts_with('!') || raw.starts_with('?') {
			i = end + 1
			continue
		}
		if raw.starts_with('/') {
			tokens << Token{kind: .end_tag, tag: raw[1..].trim_space().to_lower()}
			i = end + 1
			continue
		}
		token := parse_start_tag(raw)
		tokens << token
		if is_raw_text_tag(token.tag) && !token.self_closing {
			close_marker := '</${token.tag}'
			lower_source := source.to_lower()
			close_start := lower_source.index_after(close_marker, end + 1) or { -1 }
			if close_start >= 0 {
				raw_text := source[end + 1..close_start]
				if raw_text != '' {
					tokens << Token{kind: .text, text: raw_text}
				}
				close_end := source.index_after('>', close_start + close_marker.len) or { close_start }
				tokens << Token{kind: .end_tag, tag: token.tag}
				i = close_end + 1
				continue
			}
		}
		i = end + 1
	}
	return tokens
}

fn parse_start_tag(raw string) Token {
	self_closing := raw.ends_with('/')
	clean := raw.trim_right('/').trim_space()
	mut i := 0
	for i < clean.len && clean[i] > ` ` && clean[i] != `/` {
		i++
	}
	tag := clean[..i].to_lower()
	attrs := parse_attrs(clean[i..])
	return Token{
		kind: .start_tag
		tag: tag
		attrs: attrs
		self_closing: self_closing || is_void_element(tag)
	}
}

fn parse_attrs(input string) []Attribute {
	mut attrs := []Attribute{}
	mut i := 0
	for i < input.len {
		for i < input.len && input[i] <= ` ` {
			i++
		}
		start := i
		for i < input.len && input[i] > ` ` && input[i] != `=` && input[i] != `/` {
			i++
		}
		if start == i {
			break
		}
		name := input[start..i].to_lower()
		for i < input.len && input[i] <= ` ` {
			i++
		}
		mut value := ''
		if i < input.len && input[i] == `=` {
			i++
			for i < input.len && input[i] <= ` ` {
				i++
			}
			value, i = read_attr_value(input, i)
		}
		attrs << Attribute{name: name, value: decode_entities(value)}
	}
	return attrs
}

fn read_attr_value(input string, start int) (string, int) {
	if start >= input.len {
		return '', start
	}
	quote := input[start]
	if quote == `"` || quote == `'` {
		mut i := start + 1
		for i < input.len && input[i] != quote {
			i++
		}
		end := if i < input.len { i + 1 } else { i }
		return input[start + 1..i], end
	}
	mut i := start
	for i < input.len && input[i] > ` ` {
		i++
	}
	return input[start..i], i
}

fn decode_entities(input string) string {
	mut out := []u8{cap: input.len}
	mut i := 0
	for i < input.len {
		if input[i] != `&` {
			out << input[i]
			i++
			continue
		}
		semicolon := input.index_after(';', i + 1) or { -1 }
		if semicolon < 0 || semicolon - i > 16 {
			out << input[i]
			i++
			continue
		}
		entity := input[i + 1..semicolon]
		decoded := decode_entity(entity)
		if decoded == '' {
			out << input[i]
			i++
			continue
		}
		out << decoded.bytes()
		i = semicolon + 1
	}
	return out.bytestr()
}

fn decode_entity(entity string) string {
	match entity {
		'amp' { return '&' }
		'lt' { return '<' }
		'gt' { return '>' }
		'quot' { return '"' }
		'apos' { return "'" }
		'nbsp' { return ' ' }
		else {}
	}
	if entity.starts_with('#x') || entity.starts_with('#X') {
		value := strconv.parse_int(entity[2..], 16, 32) or { return '' }
		if value >= 0 && value < 128 {
			return u8(value).ascii_str()
		}
	}
	if entity.starts_with('#') {
		value := strconv.parse_int(entity[1..], 10, 32) or { return '' }
		if value >= 0 && value < 128 {
			return u8(value).ascii_str()
		}
	}
	return ''
}

fn is_raw_text_tag(tag string) bool {
	return tag == 'script' || tag == 'style' || tag == 'textarea' || tag == 'title'
}

fn is_void_element(tag string) bool {
	return tag in ['area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta',
		'param', 'source', 'track', 'wbr']
}
