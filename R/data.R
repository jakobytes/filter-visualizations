library(RCurl)
library(duckdb)

# Location of the parquet files: an HTTP(S) URL or a local directory.
# Each table is read from <PARQUET_BASE>/<table>.parquet
PARQUET_BASE <- Sys.getenv('PARQUET_BASE', 'https://a3s.fi/filter-data/')

.db <- new.env()

# One DuckDB connection per R process, with a view for every parquet file.
connect_to_db <- function() {
  if (is.null(.db$con)) {
    # BIGINT/HUGEINT results (e.g. COUNT, SUM) as ordinary R numbers
    con <- dbConnect(duckdb::duckdb(), bigint='numeric')
    if (nchar(Sys.getenv('DUCKDB_EXTENSION_DIRECTORY')) > 0)
      dbExecute(con, sprintf("SET extension_directory = '%s'", Sys.getenv('DUCKDB_EXTENSION_DIRECTORY')))
    if (nchar(Sys.getenv('DUCKDB_MEMORY_LIMIT')) > 0)
      dbExecute(con, sprintf("SET memory_limit = '%s'", Sys.getenv('DUCKDB_MEMORY_LIMIT')))
    if (nchar(Sys.getenv('DUCKDB_THREADS')) > 0)
      dbExecute(con, sprintf('SET threads = %d', as.integer(Sys.getenv('DUCKDB_THREADS'))))
    base <- sub('/+$', '', PARQUET_BASE)
    if (grepl('^https?://', base)) {
      dbExecute(con, 'INSTALL httpfs; LOAD httpfs;')
      tables <- c('collectors', 'map_pol', 'maps', 'p_clust', 'p_col', 'p_pl',
                  'p_sim', 'p_typ', 'p_year', 'place_stats', 'places', 'pol_pl',
                  'polygons', 'poems', 'raw_meta', 'types', 'v_clust',
                  'v_clusterings', 'verse_poem', 'word_occ', 'words')
    } else {
      tables <- sub('\\.parquet$', '', list.files(base, pattern='\\.parquet$'))
    }
    for (tbl in tables) {
      dbExecute(con, sprintf("CREATE VIEW %s AS SELECT * FROM read_parquet('%s/%s.parquet')",
                             tbl, base, tbl))
    }
    .db$con <- con
  }
  .db$con
}

# MySQL's `x REGEXP 'y'` operator has no DuckDB equivalent: use regexp_matches()
to_duckdb_sql <- function(q) {
  gsub("(\\S+)\\s+REGEXP\\s+('(?:[^']|'')*')", "regexp_matches(\\1, \\2)", q, perl=TRUE)
}

query_db <- function(con, q) {
  dbGetQuery(con, to_duckdb_sql(q))
}

connect_and_query_db <- function(q) {
  query_db(connect_to_db(), q)
}

# Logging writes to the database; not available with parquet.
write_log_to_db <- function(url, rtime, user_agent) {
  invisible(NULL)
}
