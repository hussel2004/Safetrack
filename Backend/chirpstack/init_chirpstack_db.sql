-- ChirpStack Network Server database
create role chirpstack_ns with login password 'chirpstack_ns';
create database chirpstack_ns with owner chirpstack_ns;

-- ChirpStack Application Server database
create role chirpstack_as with login password 'chirpstack_as';
create database chirpstack_as with owner chirpstack_as;

-- Enable required extensions
\c chirpstack_as
create extension if not exists pg_trgm;
create extension if not exists hstore;

\c chirpstack_ns
create extension if not exists pg_trgm;
create extension if not exists hstore;
