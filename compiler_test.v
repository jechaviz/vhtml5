module vhtml5

import vperf_core

fn test_parse_document_title_text_and_attrs() {
	doc := parse_document('<!doctype html><main id="app" data-ready><h1>Hello</h1><p>A &amp; B</p><img src="x.png"></main>') or {
		panic(err.msg())
	}
	assert doc.doctype == 'html'
	assert doc.text_content().contains('Hello')
	assert doc.text_content().contains('A & B')
	main := doc.children[0].find_first('main') or { panic('missing main') }
	assert main.attr('id') or { panic('missing id') } == 'app'
	img := main.find_first('img') or { panic('missing img') }
	assert img.self_closing
}

fn test_raw_text_is_not_tokenized_as_markup() {
	doc := parse_document('<title>One &amp; Two</title><script>if (a < b) { window.ok = true; }</script>') or {
		panic(err.msg())
	}
	assert doc.title() == 'One &amp; Two'
	assert doc.children[1].children[0].text.contains('a < b')
}

fn test_emit_v_source_uses_neutral_module() {
	code := compile_to_v('<main class="app">Hi</main>', VEmitOptions{
		module_name: 'demo_doc'
		function_name: 'load_demo_document'
	}) or { panic(err.msg()) }
	assert code.contains('import vhtml5')
	assert code.contains('vhtml5.Document')
}

fn test_profiled_compile_reports_budget() {
	result := compile_to_v_profiled('<main>Hello</main>', VEmitOptions{}, vperf_core.CompilerBudget{
		max_input_bytes: 1024
		max_output_bytes: 8192
	}) or { panic(err.msg()) }
	assert result.profile.name == 'vhtml5.compile'
	assert result.profile.budget_ok
}
