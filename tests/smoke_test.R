# Smoke test of the data layer without a browser: repeats the app's startup
# (maps, types, choices) and runs every SQL visualization with default or
# sample parameter values. Run from the app directory:
#   Rscript tests/smoke_test.R
suppressPackageStartupMessages({
  library(dplyr); library(sf); library(tmap); library(plotly)
  library(stringi); library(tidyr); library(yaml); library(whisker)
})
source('R/data.R')
source('R/visualizations/map.R')
source('R/visualizations/typetree.R')

samples <- list(
  clustering = '0', collection = 'skvr', collector = 'Lönnrot, Elias',
  county_name = 'Viena', parish_name = 'Jyskyjärvi', nro = 'skvr01100020',
  pos = '5', num_collectors = '10', word = 'meri', operator = 'REGEXP',
  type_ids = '"skvr_t010100"', volume = 'I1')

config <- read_yaml('config.yaml')
con <- connect_to_db()

t <- system.time(maps <- read_maps(con))
cat(sprintf('maps: %s (%.1fs)\n',
            paste(names(maps), sapply(maps, nrow), sep='=', collapse=' '), t[3]))
t <- system.time(types <- read_types(con))
cat(sprintf('types: %d rows (%.1fs)\n', nrow(types), t[3]))
place.poly <- read_place.poly(con)
for (q in names(config$choices_queries))
  cat(sprintf('choices %s: %d rows\n', q, nrow(query_db(con, config$choices_queries[[q]]))))

errors <- 0
results <- list()
for (name in names(config$visualizations)) {
  v <- config$visualizations[[name]]
  if (v$source != 'sql' || grepl('_custom_sql$', name)) next
  params <- list()
  for (p in v$params) {
    params[[p$name]] <- if (!is.null(p$default)) p$default
                        else if (!is.null(samples[[p$name]])) samples[[p$name]]
                        else FALSE
  }
  # as make_query() in server.R
  params <- lapply(params, function(x) if (is.character(x)) gsub('"', "'", x) else x)
  q <- whisker.render(v$query, params)
  t <- system.time(res <- tryCatch(connect_and_query_db(q), error=function(e) e))
  if (inherits(res, 'error')) {
    errors <- errors + 1
    cat(sprintf('ERROR %s: %s\n', name, conditionMessage(res)))
  } else {
    # as get_data() in server.R
    if (is.numeric(res$y) && all(res$y == as.integer(res$y), na.rm=T))
      res$y <- as.integer(res$y)
    results[[name]] <- res
    cat(sprintf('ok    %-22s %6d rows %5.2fs\n', name, nrow(res), t[3]))
  }
}

# render one map and one type tree as the app does
input <- list(map__map='parishes (all)', map__breaks='', map__palette='YlOrRd',
              map__classes=5, map__style='jenks', map__var='', map__title='',
              tree__depth=2)
m <- make_map(results$map_npoems, input, maps, place.poly)
tmap_save(m, '/tmp/map_npoems.png')
cat('map rendered: /tmp/map_npoems.png\n')
tr <- make_type_tree(results$tree_types, input, types)
htmlwidgets::saveWidget(tr, '/tmp/tree_types.html', selfcontained=FALSE)
cat('tree rendered: /tmp/tree_types.html\n')
cat('errors:', errors, '\n')
