""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" sort_python_imports.vim - sorts python imports alphabetically
" Author: Krzysiek Goj <bin-krzysiek#at#poczta.gazeta.pl>
" Version: 1.1
" Last Change: 2008-05-02
" URL: http://tbw13.blogspot.com
" Requires: Python and Vim compiled with +python option
" Licence: This script is released under the Vim License.
" Installation: Put into plugin directory
" Usage:
" Use :PyFixImports, command to fix imports in the beginning of
" currently edited file.
"
" You can also use visual mode to select range of lines and then
" use <C-i> to sort imports in those lines.
"
" Changelog:
"  1.2 - bugfix: from foo import (bar, baz)
"        Now requires only python 2.3 (patch from Konrad Delong)
"  1.1 - bugfix: from foo.bar import baz
"  1.0 - initial upload
"
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
if !has('python')
    s:ErrMsg( "Error: Required vim compiled with +python" )
    finish
endif

python << EOF
import vim
import re
from sets import Set

__global_import_re = re.compile('(?P<indent>\s*)import\s(?P<items>[^#]*)(?P<comment>(#.*)?)')
__from_import_re = re.compile('(?P<indent>\s*)from\s+(?P<module>\S*)\s+import\s(?P<items>[^#]*)(?P<comment>(#.*)?)')
__boring_re = re.compile('\s*(#.*)?$')
__endl_re = re.compile('\n?$')

def sorted(l, key=lambda x: x):
    l = map(lambda x: (key(x), x), list(l))
    l.sort()
    l = map(lambda pair: pair[1], l)
    return l


def is_global_import(line):
    """checks if line is a 'import ...'"""
    return __global_import_re.match(line) is not None


def is_from_import(line):
    """checks if line is a 'from ... import ...'"""
    return __from_import_re.match(line) is not None


def is_boring(line):
    """checks if line is boring (empty or comment)"""
    return __boring_re.match(line) is not None


def has_leading_ws(line):
    if not line: return False
    return line[0].isspace()


def is_unindented_import(line):
    """checks if line is an unindented import"""
    return not has_leading_ws(line) and (is_global_import(line) or is_from_import(line))


def make_template(indent, comment):
    """makes template out of indentation and comment"""
    if comment:
	comment = ' ' + comment
    return indent + '%s' + comment


def _split_import(regex, line):
    """splits import line (using regex) intro triple: module (may be None), set_of_items, line_template"""
    imports = regex.match(line)
    if not imports:
        raise ValueError, 'this line isn\'t an import'
    indent, items, comment = map(lambda name: imports.groupdict()[name], 'indent items comment'.split())
    module = imports.groupdict().get('module')
    if items.startswith('(') and items.endswith(')'):
        items = items[1:-1]
    return module, Set(map(lambda item: item.strip(), items.split(','))), make_template(indent, comment)


def split_globals(line):
    """splits 'import ...' line intro pair: set_of_items, line_template"""
    return _split_import(__global_import_re, line)[1:] # ignore module


def split_from(line):
    """splits 'from ... import ...' line intro triple: module_name, set_of_items, line_template"""
    return _split_import(__from_import_re, line)


def get_lines(lines):
    """returns numbers -- [from, to) -- of first lines with unindented imports"""
    start, end = 0, 0
    start_found = False
    for num, line in enumerate(lines):
        if is_unindented_import(line):
            if not start_found:
                start = num
		start_found = True
            end = num + 1
        elif end and not is_boring(line):
            break
    return start, end


def sort_and_join(items):
    """returns alphabetically (case insensitive) sorted and comma-joined collection"""
    return ', '.join(sorted(items, key=lambda x: x.upper()))


def make_global_import(items, template='%s'):
    return template % 'import %s' % sort_and_join(items)


def make_from_import(module, items, template='%s'):
    return template % 'from %s import %s' % (module, sort_and_join(items))


def repair_any(line):
    """repairs any import line (doesn't affect boring lines)"""
    suffix = __endl_re.search(line).group()
    if is_global_import(line):
        return make_global_import(*split_globals(line)) + suffix
    elif is_from_import(line):
        return make_from_import(*split_from(line)) + suffix
    elif is_boring(line):
        return line
    else:
        raise ValueError, '"%s" isn\'t an import line' % line.rstrip()


def fixed(lines):
    """returns fixed lines"""
    def rank(line):
        if is_global_import(line): return 2
        if is_from_import(line): return 1
        if is_boring(line): return 0
    lines = filter(lambda line: line.strip(), lines)
    lines = map(lambda line: repair_any(line), lines)
    return sorted(lines, key=lambda x: (-rank(x), x.upper()))


def fix_safely(lines):
    """fixes all unindented imports in the beginning of list of lines"""
    start, end = get_lines(lines)
    lines[start:end] = fixed(lines[start:end])
EOF

command! PyFixImports python fix_safely(vim.current.buffer)
autocmd FileType python,scons vnoremap <C-i> :python vim.current.range[:]=fixed(vim.current.range)<CR>
