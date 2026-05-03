- initdb.d/: it contains a script to [enable the vector extension][1] for pg.
  The script is executed automatically when a new pg database is created.
- backup.sh: dump the database to OneDrive zipped.
- compose.yaml: the compose file to start the services. `restart: unless-stopped` ensures
  the services are started automatically when docker desktop starts.
- .env: environment variables for the services. Keys inside are generated using `openssl rand -base64 32`.

[1]: https://github.com/pgvector/pgvector#getting-started
