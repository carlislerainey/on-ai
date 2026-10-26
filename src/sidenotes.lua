-- sidenotes.lua -- pandoc filter for the margin-note template.
--
--   ::: aside            -> \aside{...} at the end of the paragraph (or the
--   text of the aside       last list item) just above the div
--   :::
--
--   [CTK: ...]           -> \ctk{CTK: ...}, a red drafting note
--
--   @key, [@key]         -> \citet / \citep, plus \aside{\bibentry{key}}
--                           at each work's first citation; a citation in a
--                           footnote gets its aside beside the footnote mark

local function latex(blocks)
  local out = pandoc.write(pandoc.Pandoc(blocks), 'latex',
    pandoc.WriterOptions({ cite_method = 'natbib' }))
  return (out:gsub('%s+$', ''))
end

local function latex_inlines(inlines)
  return latex({ pandoc.Plain(inlines) })
end

-- [CTK: ...] cues: gather the inlines from a Str starting "[CTK:" through
-- the first Str ending "]".
function Inlines(inlines)
  -- Split "text.[CTK:" (no space before the cue) into "text." and "[CTK:".
  local split = pandoc.List()
  for _, el in ipairs(inlines) do
    local at = el.t == 'Str' and el.text:find('[CTK:', 2, true)
    if at then
      split:insert(pandoc.Str(el.text:sub(1, at - 1)))
      split:insert(pandoc.Str(el.text:sub(at)))
    else
      split:insert(el)
    end
  end
  inlines = split

  local out = pandoc.List()
  local i = 1
  while i <= #inlines do
    local el = inlines[i]
    if el.t == 'Str' and el.text:match('^%[CTK:') then
      local j = i
      while j <= #inlines and not (inlines[j].t == 'Str' and inlines[j].text:match('%]$')) do
        j = j + 1
      end
      if j > #inlines then
        out:insert(el)  -- no closing bracket in this paragraph; leave as is
        i = i + 1
      else
        local cue = pandoc.List()
        for k = i, j do cue:insert(inlines[k]) end
        cue[1] = pandoc.Str(cue[1].text:sub(2))
        cue[#cue] = pandoc.Str(cue[#cue].text:sub(1, -2))
        if cue[#cue].text == '' then cue:remove(#cue) end
        out:insert(pandoc.RawInline('latex', '\\ctk{' .. latex_inlines(cue) .. '}'))
        i = j + 1
      end
    else
      out:insert(el)
      i = i + 1
    end
  end
  return out
end

-- Full references in the margin: after a citation (or a footnote that holds
-- one), an \aside with the reference for each work not yet cited.
local cited = {}

local function refnotes(el)
  local out = pandoc.List()
  for _, inline in ipairs(el.content) do
    out:insert(inline)
    if inline.t == 'Cite' or inline.t == 'Note' then
      pandoc.Inlines({ inline }):walk({
        Cite = function(cite)
          for _, c in ipairs(cite.citations) do
            if not cited[c.id] then
              cited[c.id] = true
              out:insert(pandoc.RawInline('latex',
                '\\aside{\\bibentry{' .. c.id .. '}}'))
            end
          end
        end,
      })
    end
  end
  el.content = out
  return el, false  -- don't descend: footnotes are handled from here
end

local function skip_aside(div)
  if div.classes:includes('aside') then return div, false end
end

-- The block an aside attaches to: a paragraph, or the last paragraph of
-- the last item of a list.
local function anchor(block)
  if block.t == 'Para' or block.t == 'Plain' then
    return block
  elseif block.t == 'OrderedList' or block.t == 'BulletList' then
    local item = block.content[#block.content]
    return anchor(item[#item])
  end
end

function Blocks(blocks)
  local out = pandoc.List()
  for _, block in ipairs(blocks) do
    if block.t == 'Div' and block.classes:includes('aside') then
      local target = #out > 0 and anchor(out[#out])
      if not target then
        error('an ::: aside div must follow a paragraph or a list')
      end
      target.content:insert(pandoc.RawInline('latex',
        '\\aside{' .. latex(block.content) .. '}'))
    else
      out:insert(block)
    end
  end
  return out
end

return {
  { Inlines = Inlines },
  { traverse = 'topdown', Div = skip_aside, Para = refnotes, Plain = refnotes },
  { Blocks = Blocks },
}
