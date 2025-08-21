-- MangaOnlineTeam Aidoku Source
-- Minimal, robust implementation. Tweak selectors as needed.

local base = "https://mangaonlineteam.com"

function register()
  module.Name = "MangaOnlineTeam"
  module.Id = "mangaonlineteam"
  module.Language = "en"
  module.Domains = { "mangaonlineteam.com" }
end

-- helper: fetch & parse
local function get_doc(url)
  local res = http.get(url)
  if not res or res.status ~= 200 then
    return nil
  end
  return dom.parse(res.text)
end

-- Popular (listing) - page is 1-based
function getPopularManga(page)
  page = page or 1
  local url = base .. "/page/" .. tostring(page) .. "/"
  local doc = get_doc(url)
  if not doc then return {} end

  local results = {}
  for el in doc:select("article a[href*='/manga/']") do
    local href = el:getattr("href")
    local title = nil
    local h2 = el:select_first("h2")
    if h2 then title = h2:text() else title = el:text() end
    local img = el:select_first("img") and el:select_first("img"):getattr("src") or nil
    if href and title then
      table.insert(results, { id = href, url = href, title = title, description = "", image = img })
    end
  end

  -- fallback for different HTML structures
  if #results == 0 then
    for el in doc:select(".post-thumb a[href*='/manga/']") do
      local href = el:getattr("href")
      local img = el:select_first("img") and el:select_first("img"):getattr("src") or nil
      local title = img and (el:select_first("img"):getattr("alt") or "") or href
      if href then table.insert(results, { id = href, url = href, title = title, image = img }) end
    end
  end

  return results
end

-- Search (try WP-style ?s= first)
function searchManga(query, page)
  local q = http.url_encode(query)
  local url = base .. "/?s=" .. q .. "&post_type%5B%5D=manga"
  local doc = get_doc(url)
  local results = {}
  if not doc then return results end

  for el in doc:select("article a[href*='/manga/']") do
    local href = el:getattr("href")
    local title = el:select_first("h2") and el:select_first("h2"):text() or el:text()
    local img = el:select_first("img") and el:select_first("img"):getattr("src") or nil
    if href and title then table.insert(results, { id = href, url = href, title = title, image = img }) end
  end

  return results
end

-- Manga details + chapters
function getMangaDetails(url)
  local doc = get_doc(url)
  if not doc then return nil end

  local title = doc:select_first("h1") and doc:select_first("h1"):text() or ""
  local summary_el = doc:select_first(".entry-content") or doc:select_first(".summary") or doc
  local summary = summary_el and summary_el:text() or ""

  local thumb_el = doc:select_first(".page-image img") or doc:select_first(".post-thumb img") or doc:select_first("img")
  local thumb = thumb_el and thumb_el:getattr("src") or nil

  local chapters = {}
  for ch in doc:select(".wp-manga-chapter a, a[href*='chapter']") do
    local href = ch:getattr("href")
    local ch_title = ch:text()
    if href then table.insert(chapters, { id = href, url = href, name = ch_title, date = nil }) end
  end

  -- If chapters found newest-first, reverse them (Aidoku expects older->newer)
  local rev = {}
  for i = #chapters, 1, -1 do table.insert(rev, chapters[i]) end

  return { id = url, url = url, title = title, description = summary, image = thumb, chapters = rev }
end

-- Pages for a chapter
function getPages(url)
  local doc = get_doc(url)
  if not doc then return {} end

  local pages = {}
  for img in doc:select("article img, .entry-content img, .reading-content img, .reader-area img") do
    local src = img:getattr("src") or img:getattr("data-src") or img:getattr("data-srcset")
    if src and src:len() > 0 then table.insert(pages, { image = src }) end
  end

  -- fallback selectors
  if #pages == 0 then
    for img in doc:select(".wp-manga-chapter img, figure img") do
      local src = img:getattr("src") or img:getattr("data-src")
      if src and src:len() > 0 then table.insert(pages, { image = src }) end
    end
  end

  return pages
end

-- Latest updates: reuse popular listing
function getLatestUpdates(page)
  return getPopularManga(page)
end
