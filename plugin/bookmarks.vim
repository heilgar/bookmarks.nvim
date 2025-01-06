if exists('g:loaded_bookmarks') | finish | endif
let g:loaded_bookmarks = 1

command! BookmarkAdd lua require('bookmarks').add_bookmark()
command! BookmarkRemove lua require('bookmarks').remove_bookmark()
command! Bookmarks Telescope bookmarks

lua require('bookmarks')

