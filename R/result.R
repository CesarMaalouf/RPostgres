#' PostgreSQL results.
#'
#' @keywords internal
#' @include connection.R
#' @export
setClass("PqResult",
  contains = "DBIResult",
  slots = list(
    ptr = "externalptr",
    sql = "character"
  )
)

#' @rdname PqResult-class
#' @export
setMethod("dbGetStatement", "PqResult", function(res, ...) {
  res@sql
})

#' @rdname PqResult-class
#' @export
setMethod("dbIsValid", "PqResult", function(dbObj, ...) {
  result_active(dbObj@ptr)
})

#' @rdname PqResult-class
#' @export
setMethod("dbGetRowCount", "PqResult", function(res, ...) {
  result_rows_fetched(res@ptr)
})

#' @rdname PqResult-class
#' @export
setMethod("dbGetRowsAffected", "PqResult", function(res, ...) {
  result_rows_affected(res@ptr)
})

#' @rdname PqResult-class
#' @export
setMethod("dbColumnInfo", "PqResult", function(res, ...) {
  result_column_info(res@ptr)
})

#' @rdname PqResult-class
#' @export
setMethod("show", "PqResult", function(object) {
  cat("<PqResult>\n")
  if(!dbIsValid(object)){
    cat("EXPIRED\n")
  } else {
    cat("  SQL  ", dbGetStatement(object), "\n", sep = "")

    done <- if (dbHasCompleted(object)) "complete" else "incomplete"
    cat("  ROWS Fetched: ", dbGetRowCount(object), " [", done, "]\n", sep = "")
    cat("       Changed: ", dbGetRowsAffected(object), "\n", sep = "")
  }
  invisible(NULL)
})

#' Execute a SQL statement on a database connection
#'
#' To retrieve results a chunk at a time, use \code{dbSendQuery},
#' \code{dbFetch}, then \code{ClearResult}. Alternatively, if you want all the
#' results (and they'll fit in memory) use \code{dbGetQuery} which sends,
#' fetches and clears for you.
#'
#' @param conn A \code{\linkS4class{PqConnection}} created by \code{dbConnect}.
#' @param statement An SQL string to execture
#' @param params A list of query parameters to be substituted into
#'   a parameterised query. Query parameters are sent as strings, and the
#'   correct type is imputed by PostgreSQL. If this fails, you can manually
#'   cast the parameter with e.g. \code{"$1::bigint"}.
#' @param ... Another arguments needed for compatibility with generic (
#'   currently ignored).
#' @examples
#' db <- dbConnect(RPostgres::Postgres())
#' dbWriteTable(db, "usarrests", datasets::USArrests, temporary = TRUE)
#'
#' # Run query to get results as dataframe
#' dbGetQuery(db, "SELECT * FROM usarrests LIMIT 3")
#'
#' # Send query to pull requests in batches
#' res <- dbSendQuery(db, "SELECT * FROM usarrests")
#' dbFetch(res, n = 2)
#' dbFetch(res, n = 2)
#' dbHasCompleted(res)
#' dbClearResult(res)
#'
#' dbRemoveTable(db, "usarrests")
#'
#' dbDisconnect(db)
#' @name postgres-query
NULL

#' @export
#' @rdname postgres-query
setMethod("dbSendQuery", "PqConnection", function(conn, statement, params = NULL, ...) {
  statement <- enc2utf8(statement)

  rs <- new("PqResult",
    ptr = result_create(conn@ptr, statement),
    sql = statement)

  if (!is.null(params)) {
    dbBind(rs, params)
  }

  rs
})

#' @export
#' @rdname postgres-query
setMethod("dbGetQuery", signature("PqConnection", "character"),
  function(conn, statement, ..., params = NULL, row.names = NA) {
    rs <- dbSendQuery(conn, statement, params = params, ...)
    on.exit(dbClearResult(rs))

    dbFetch(rs, n = -1, ..., row.names = row.names)
  }
)

#' @param res Code a \linkS4class{PqResult} produced by
#'   \code{\link[DBI]{dbSendQuery}}.
#' @param n Number of rows to return. If less than zero returns all rows.
#' @inheritParams SQL::rownamesToColumn
#' @export
#' @rdname postgres-query
setMethod("dbFetch", "PqResult", function(res, n = -1, ..., row.names = NA) {
  SQL::columnToRownames(result_fetch(res@ptr, n = n), row.names)
})

#' @rdname postgres-query
#' @export
setMethod("dbBind", "PqResult", function(res, params, ...) {
  params <- lapply(params, as.character)
  result_bind_params(res@ptr, params)
  invisible(res)
})


#' @rdname postgres-query
#' @export
setMethod("dbHasCompleted", "PqResult", function(res, ...) {
  result_active(res@ptr)
})

#' @rdname postgres-query
#' @export
setMethod("dbClearResult", "PqResult", function(res, ...) {
  result_release(res@ptr)
  TRUE
})
