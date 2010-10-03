# -*- coding: utf-8 -*-

require 'cairo'
require 'pango'

class Pango::Rectangle
  def inspect
    s = super
    t = [
      "ascent=#{Pango.pixels self.ascent}",
      "descent=#{Pango.pixels self.descent}",
      "height=#{Pango.pixels self.height}",
      "lbearing=#{Pango.pixels self.lbearing}",
      "rbearing=#{Pango.pixels self.rbearing}",
      "width=#{Pango.pixels self.width}",
      "x=#{Pango.pixels self.x}",
      "y=#{Pango.pixels self.y}"
    ].join(' ')
    s[-1,0] = " #{t}"
    s
  end
end

fontmap = Pango::CairoFontMap.create
pango = fontmap.create_context
pango.resolution = 72
text = "AB12あいう".force_encoding("ASCII-8BIT")
attrlist = Pango::AttrList.new
attrlist.insert(Pango::AttrFamily.new("Optima,ヒラギノ角ゴ ProN"))
attrlist.insert(Pango::AttrSize.new(16*Pango::SCALE))
items = pango.itemize(text, 0, text.bytesize, attrlist)
items.each do |x|
  p text[x.offset, x.length].force_encoding("UTF-8")
  p x.analysis.font.describe.to_s.force_encoding("UTF-8")
  gs = Pango.shape(text[x.offset, x.length], x.analysis)
  p *gs.extents(x.analysis.font)
end
# {{{1
# vim: foldmethod=marker
