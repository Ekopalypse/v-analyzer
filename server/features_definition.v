module server

import lsp
import loglib
import analyzer.psi

pub fn (mut ls LanguageServer) definition(params lsp.TextDocumentPositionParams, mut wr ResponseWriter) ?[]lsp.LocationLink {
	uri := params.text_document.uri.normalize()
	file := ls.get_file(uri) or { return none }

	offset := file.find_offset(params.position)
	element := file.psi_file.find_reference_at(offset) or {
		loglib.with_fields({
			'offset': offset.str()
		}).warn('cannot find reference')
		return none
	}

	element_text_range := element.text_range()

	resolved := element.resolve() or {
		loglib.with_fields({
			'caller': @METHOD
			'name':   element.name()
		}).warn('cannot resolve reference')
		return none
	}

	data := new_resolve_result(resolved.containing_file(), resolved) or { return [] }
	return [
		data.to_location_link(element_text_range),
	]
}

struct ResolveResult {
pub:
	filepath string
	name     string
	range    psi.TextRange
}

pub fn new_resolve_result(containing_file &psi.PsiFileImpl, element psi.PsiElement) ?ResolveResult {
	if element is psi.PsiNamedElement {
		text_range := element.identifier_text_range()
		return ResolveResult{
			range: text_range
			filepath: containing_file.path()
			name: element.name()
		}
	}

	return none
}

fn (r &ResolveResult) to_location_link(origin_selection_range psi.TextRange) lsp.LocationLink {
	range := text_range_to_lsp_range(r.range)
	return lsp.LocationLink{
		target_uri: 'file://' + r.filepath
		origin_selection_range: text_range_to_lsp_range(origin_selection_range)
		target_range: range
		target_selection_range: range
	}
}