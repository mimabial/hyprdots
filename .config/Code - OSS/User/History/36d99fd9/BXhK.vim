let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/.local/share/icons
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +1 ~/.config/waybar/config.jsonc
badd +1 ~/.config/waybar/includes/global.css
badd +291 ~/.config/waybar/includes/border-radius.css
badd +1 ~/.config/waybar/includes/includes.json
badd +1 ~/.local/share/waybar/modules/custom-powermenu.jsonc
badd +1 ~/.local/share/waybar/modules/custom-power.jsonc
badd +69 ~/.local/share/waybar/menus/power.xml
badd +62 ~/.local/share/waybar/layouts/hyprdots/01.jsonc
badd +1 ~/.local/share/waybar/layouts/hyprdots/17.jsonc
badd +54 ~/.local/share/waybar/layouts/hyprdots/16.jsonc
badd +1 ~/.local/share/waybar/layouts/hyprdots/15.jsonc
badd +1 ~/.local/share/waybar/layouts/test.jsonc
badd +60 ~/.local/bin/denv-shell
badd +1 ~/.local/lib/denv/lockscreen.sh
argglobal
%argdel
$argadd .
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20
let &shortmess = s:shortmess_save
let &winminheight = s:save_winminheight
let &winminwidth = s:save_winminwidth
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
set hlsearch
nohlsearch
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
