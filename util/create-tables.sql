drop table if exists term;
create table term(
    entity_id integer not null,
    entity_languages text,
    entity_language_count integer,
    term_type integer,
    term_language text,
    term_text text,
    term_text_alphanum text,
    description text,
    site_url text
);
vacuum;