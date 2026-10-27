# filter-visualizations (Shiny) reading parquet files with DuckDB
# Build with: docker build -t dhh26-visualizations .

FROM quay.io/hsci/shiny-verse:4.2.3

RUN apt-get update && apt-get -y --no-install-recommends install \
    libnss-wrapper \
    gettext-base \
    libjq-dev \
    libudunits2-0 \
    libproj-dev \
    libgdal-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN install2.r --error \
    DT \
    jqr \
    ggplot2 \
    RCurl \
    sf \
    stringi \
    yaml \
    shinyAce \
    shinyjs \
    shinybrowser \
    tmap \
    httr \
    tmaptools \
    xml2 \
    plotly \
    pacman \
    whisker \
    wordcloud2

# The image's CRAN snapshot (2023) has an old DuckDB; the queries need 1.x
# (e.g. MATERIALIZED CTEs). Prefer Posit Package Manager's current binaries.
ARG DUCKDB_REPO=https://packagemanager.posit.co/cran/__linux__/jammy/latest
RUN R -q -e "install.packages('duckdb', repos='${DUCKDB_REPO}'); \
    stopifnot(packageVersion('duckdb') >= '1.0.0'); \
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir=':memory:'); \
    DBI::dbExecute(con, \"SET extension_directory = '/opt/duckdb_extensions'\"); \
    DBI::dbExecute(con, 'INSTALL httpfs')" \
    && chmod -R a+rX /opt/duckdb_extensions

ENV DUCKDB_EXTENSION_DIRECTORY=/opt/duckdb_extensions

COPY app.R /srv/shiny-server/
COPY config.yaml /srv/shiny-server/
COPY about.html /srv/shiny-server/
COPY R/ /srv/shiny-server/R/
COPY www/ /srv/shiny-server/www/
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf
COPY passwd.template /passwd.template
COPY shiny-server.sh /usr/bin/shiny-server.sh

# OpenShift runs as a random non-root UID
RUN chmod a+x /usr/bin/shiny-server.sh && \
    mkdir -p /var/log/shiny-server /var/lib/shiny-server && \
    chmod a+rwx /var/log/shiny-server /var/lib/shiny-server /srv/shiny-server

EXPOSE 3838

CMD ["/usr/bin/shiny-server.sh"]
