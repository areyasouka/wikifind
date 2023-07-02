# pip3.9 install qwikidata regex ujson
# pip_pypy3 install qwikidata regex ujson
# /usr/local/Cellar/python@3.9/3.9.7_1/bin/python3 -m pip install ujson qwikidata regex
# pypy3 util/extractwikifind.py data/test-100.json.gz data/wikidata_term.tsv.gz

# vi /usr/local/lib/python3.9/site-packages/qwikidata/json_dump.py
# vi /opt/homebrew/lib/python3.9/site-packages/qwikidata/json_dump.py
# import ujson as json

import sys
import time
import regex
import gzip

from qwikidata.entity import WikidataItem
from qwikidata.json_dump import WikidataJsonDump
from qwikidata.utils import dump_entities_to_json

req_num_langs = 2
REQUIRE_ALL_LANG = ("en", )
REQUIRE_ONE_LANG = ("ja", "zh", "ko")
LANGUAGES = ("en", "ja", "zh", "ko", "es", "fr", "de")

def has_id(item: WikidataItem, id: str) -> bool:
    # >>> q42.entity_id # 'Q42'
    # >>> q42.entity_type # 'item'
    # >>> q42.get_label() # 'Douglas Adams'
    # >>> q42.get_description("en") # 'author and humorist'
    # >>> q42.get_aliases() # ['Douglas Noël Adams', 'Douglas Noel Adams', 'Douglas N. Adams']
    # >>> q42.get_enwiki_title() # 'Douglas Adams'
    # >>> q42.get_sitelinks()["enwiki“"]["url"] # 'https://en.wikipedia.org/wiki/Douglas_Adams'
    return item.entity_id == id

def dump_entities_tsv(wjd_dump_path=None, req_all_lang=None, req_one_lang=None, langs=None, tsv_path=None, limit=None):
    out = gzip.open(tsv_path, "wt")
    wjd = WikidataJsonDump(wjd_dump_path)
    t1 = time.time()
    term_count = 0
    req_onelangwikis = set(l+"wiki" for l in req_one_lang)
    req_alllangwikis = set(l+"wiki" for l in req_all_lang)
    for ii, entity_dict in enumerate(wjd):
        if limit:
            print(entity_dict)
            if ii > limit:
                break
            continue
        if entity_dict["type"] == "item":
            entity = WikidataItem(entity_dict)
            sitelinks = entity._entity_dict["sitelinks"] or {}
            if (not req_alllangwikis or req_alllangwikis.issubset(sitelinks)) \
                    and (not req_onelangwikis or req_onelangwikis.intersection(sitelinks)) \
                    and len(sitelinks) >= req_num_langs:
                sl = [sitelinks[l+"wiki"]["title"] for l in langs if l+"wiki" in sitelinks]
                descs = entity._entity_dict["descriptions"] or {}
                if not sl[0].startswith("Category:") and not sl[0].startswith("Template:") and not sl[0].startswith("Help:") \
                        and ("en" not in descs \
                            or not (descs["en"]["value"].startswith("Wikipedia disambiguation") \
                                    or descs["en"]["value"].startswith("Wikimedia disambiguation")) \
                            ):
                    langs = sorted(langs)
                    langscsv = ','.join(langs)
                    langs_count = str(len(langs))
                    for lang in langs:
                        label = entity.get_label(lang)
                        if label:
                            aliases = entity.get_aliases(lang)
                            for txt, term_type in zip([label]+aliases, ["1"]+len(aliases)*["2"]):
                                txtalphanum = regex.sub(r'[^\p{Alphabetic}\p{Digit}]', "", txt).lower()
                                desc = entity.get_description(lang) if term_type == "1" else ""
                                sitelink = sitelinks[lang+"wiki"]["title"] if term_type == "1" and lang+"wiki" in sitelinks else ""
                                out.write(
                                    entity.entity_id[1:]
                                    +'\t'+langscsv
                                    +'\t'+langs_count
                                    +'\t'+term_type
                                    +'\t'+lang
                                    +'\t"'+(txt.replace('"', '""') if txt != txtalphanum else "")+'"'
                                    +'\t'+txtalphanum
                                    +'\t"'+desc.replace('"', '""')+'"'
                                    +'\t"'+(sitelink.replace('"', '""') if sitelink != txt else "")+'"'
                                    +'\n')
                                term_count += 1
                            
        if ii % 10000 == 0:
            t2 = time.time()
            dt = t2 - t1
            print("found {:,.0f} terms for {:,.0f}/~81m total entities [entities/s: {:,.0f}]".format(term_count, ii, ii / dt))
        # if ii > 10000:
        #     break
    out.close()
    print(wjd_dump_path)
    print(tsv_path)

if __name__ == "__main__":
    wjd_dump_path = sys.argv[1] 
    # wjd_dump_path = "./data/latest-all.json.gz" 
    # wjd_dump_path = "./data/test-100.json.gz"
    # wjd_dump_path = "./data/latest-all.json.gz.part-ab.json.gz"
    tsv_path = sys.argv[2] 
    # tsv_path = "./data/wikidata_term.tsv"
    dump_entities_tsv(
            wjd_dump_path=wjd_dump_path,
            req_all_lang=REQUIRE_ALL_LANG,
            req_one_lang=REQUIRE_ONE_LANG, 
            langs=LANGUAGES, 
            tsv_path=tsv_path,
            limit=None)
