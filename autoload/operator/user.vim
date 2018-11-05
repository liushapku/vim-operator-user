" operator-user - Define your own operator easily
" Version: 0.1.0
" Copyright (C) 2009-2015 Kana Natsuno <http://whileimautomaton.net/>
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
" Interface  "{{{1
function! operator#user#define(name, function_name, ...)  "{{{2
  return call('operator#user#_define',
  \           ['<Plug>(operator-' . a:name . ')', a:function_name] + a:000)
endfunction




function! operator#user#define_ex_command(name, ex_command)  "{{{2
  return operator#user#define(
  \        a:name,
  \        'operator#user#_do_ex_command',
  \        'call operator#user#_set_ex_command(' . string(a:ex_command) . ')'
  \      )
endfunction




function! operator#user#register()  "{{{2
  return s:register
endfunction




function! operator#user#visual_command_from_wise_name(wise_name)  "{{{2
  if a:wise_name ==# 'char'
    return 'v'
  elseif a:wise_name ==# 'line'
    return 'V'
  elseif a:wise_name ==# 'block'
    return "\<C-v>"
  else
    echoerr 'operator-user:E1: Invalid wise name:' string(a:wise_name)
    return 'v'  " fallback
  endif
endfunction








" Misc.  "{{{1
" Support functions for operator#user#define()  "{{{2
function! operator#user#_define(operator_keyseq, function_name, ...)
  if 0 < a:0
    let additional_settings = '\|' . join(a:000)
  else
    let additional_settings = ''
  endif

  execute printf(('nnoremap <script> <silent> %s ' .
  \               ':<C-u>call operator#user#_set_up(%s)%s<Return>' .
  \               '<SID>(count)' .
  \               '<SID>(register)' .
  \               'g@'),
  \              a:operator_keyseq,
  \              string(a:function_name),
  \              additional_settings)
  execute printf(('vnoremap <script> <silent> %s ' .
  \               ':<C-u>call operator#user#_set_up(%s)%s<Return>' .
  \               'gv' .
  \               '<SID>(register)' .
  \               'g@'),
  \              a:operator_keyseq,
  \              string(a:function_name),
  \              additional_settings)
  "execute printf('onoremap %s  g@', a:operator_keyseq)
  " restrict omap to be effective only when it is after the same map.
  " otherwise cancel it
  execute printf('onoremap <expr> %s (v:operator == "g@" && &opfunc == "%s")? "g@" : "\<esc>"',
              \  a:operator_keyseq, a:function_name)
endfunction


function! operator#user#_set_up(operator_function_name)
  let &operatorfunc = a:operator_function_name
  let s:count = v:count
  let s:register = v:register
endfunction




" Support functions for operator#user#define_ex_command()  "{{{2
function! operator#user#_do_ex_command(motion_wiseness)
  execute "'[,']" s:ex_command
endfunction


function! operator#user#_set_ex_command(ex_command)
  let s:ex_command = a:ex_command
endfunction




" Variables  "{{{2

" See operator#user#_do_ex_command() and operator#user#_set_ex_command().
" let s:ex_command = ''

" See operator#user#_set_up() and s:count()
" let s:count = ''

" See operator#user#_set_up() and s:register()
" let s:register = ''




" count  "{{{2
function! s:count()
  return s:count ? s:count : ''
endfunction

nnoremap <expr> <SID>(count)  <SID>count()

" FIXME: It's hard for user-defined operator to handle count in Visual mode.
" nnoremap <expr> <SID>(count)  <SID>count()




" register designation  "{{{2
function! s:register()
  return s:register == '' ? '' : '"' . s:register
endfunction

nnoremap <expr> <SID>(register)  <SID>register()
vnoremap <expr> <SID>(register)  <SID>register()




" <SID>  "{{{2
function! operator#user#_sid_prefix()
  return s:SID_PREFIX()
endfunction


function! s:SID_PREFIX()
  return matchstr(expand('<sfile>'), '\%(^\|\.\.\)\zs<SNR>\d\+_\zeSID_PREFIX$')
endfunction


" new api ====================================================

" called in imap or nmap
function! s:setpos(info, start, end, motion_wiseness)
  let pos1 = getpos("'".a:start)
  let pos2 = getpos("'".a:end)
  if pos1[1] > pos2[1] || (pos1[1] == pos2[1] && pos1[2] > pos2[2])
    let a:info['start'] = pos2
    let a:info['end'] = pos1
  else
    let a:info['start'] = pos1
    let a:info['end'] = pos2
  endif
  let a:info['motion_wiseness'] = a:motion_wiseness
endfunction

" mode: i for imap, v for vmap, n for nmap
" (omap does not call this function)
"
" will be augumented with 'start', 'end' and 'motion_wiseness'
function! s:init_info(callback, mode)
  let rv = {
        \ 'call' : function(a:callback),
        \ 'cursor': getpos("."),
        \ 'count': v:count,
        \ 'count1': v:count1,
        \ 'register': v:register,
        \ 'mode' : a:mode,
        \ 'virtualedit': &virtualedit,
        \ }
  return rv
endfunction

function! operator#user#operatorfunc(motion_wiseness) abort
  let F = s:info['call']
  call s:setpos(s:info, '[', ']', a:motion_wiseness)
  try
    call F(s:info)
  finally
    if s:info['mode'] == 'i'
      let &virtualedit = s:info['virtualedit']
    endif
    unlet s:info
  endtry
endfunction

function! operator#user#nmap(callback)
  set operatorfunc=operator#user#operatorfunc
  let s:info = s:init_info(a:callback, 'n')
  return "g@"
endfunction
function! operator#user#imap(callback)
  set operatorfunc=operator#user#operatorfunc
  let s:info = s:init_info(a:callback, 'i')
  let &virtualedit = 'onemore'
  return "\<c-o>g@"
endfunction
function! operator#user#omap(callback)
  if v:operator == "g@" && &operatorfunc == 'operator#user#operatorfunc' &&
        \ s:info['call'] == function(a:callback)
    return "g@"
  else
    return "\<esc>"
  endif
endfunction


let s:motion_wiseness = {'v': 'char', 'V': 'line', "\<c-v>": 'block'}
let s:visual_mode = { 'char':'v', 'line': 'V', 'block': "\<c-v>"}
" this function is called in normal mode, since we didn't use <expr>-map
function! operator#user#vmap(callback)
  let info = s:init_info(a:callback, 'v')
  call s:setpos(info, "<", ">", s:motion_wiseness[visualmode()])
  2Log info
  let F = function(a:callback)
  call F(info)
endfunction
function! operator#user#visual_select(info) abort
  if a:info['mode'] == 'v'
    normal gv
  else
    call setpos("'<", a:info['start'])
    call setpos("'>", a:info['end'])
    let mode = s:visual_mode[a:info['motion_wiseness']]
    let rv = "gv" . (mode == visualmode()? '' : mode)
    exe "normal" rv
  endif
endfunction

function! operator#user#keyseq_from_name(name)
  return '<Plug>(operator-' . a:name . ')'
endfunction
function! operator#user#define_callback(keyseq, callback, ...)
  let keyseq = a:keyseq
  let funcname = string(a:callback)
  let modes = get(a:000, 0, 'nvo')
  if modes =~ 'n'
    execute printf('nnoremap <script> <silent> <expr> %s operator#user#nmap(%s)', keyseq, funcname)
  endif
  if modes =~ 'o'
    execute printf('onoremap <script> <silent> <expr> %s operator#user#omap(%s)', keyseq, funcname)
  endif
  if modes =~ 'i'
    execute printf('inoremap <script> <silent> <expr> %s operator#user#imap(%s)', keyseq, funcname)
  endif
  if modes =~ 'v'
    execute printf('vnoremap <script> <silent> %s :<c-u>call operator#user#vmap(%s)<cr>', keyseq, funcname)
  endif
endfunction


function! operator#user#default_callback(info)
  echo a:info
endfunction
call operator#user#define_callback(';o', 'operator#user#default_callback', 'novi')

" __END__  "{{{1
" vim: foldmethod=marker
