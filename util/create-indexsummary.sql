-- create index term_entity_id on term(entity_id, term_language, term_type);
-- create index term_entity_search on term(term_language, entity_languages, term_text_alphanum);
drop table if exists summary;
create table summary as 
    select term_language, term_type, count(1) as term_type_count 
    from term 
    group by term_type, term_language 
    order by term_type, term_type_count desc;
drop table if exists meta;
create table meta (version integer not null);
insert into meta (version) values (strftime('%Y%m%d', 'now'));
vacuum;
