# misc util to extract character usage counts and language combinations

from __future__ import print_function

def langcombos():
	import itertools
	langs = ["en", "ja", "zh", "ko", "es", "fr", "de"]

	return sorted(map(lambda l: ','.join(sorted(l)), sum([list(itertools.combinations(langs, r)) for r in range(2, 8)], [])))


import sqlite3
from collections import defaultdict
from pprint import pprint as pp

TOP_CHRS = 250

c = sqlite3.connect('./data/wdsqlite.db')
d = defaultdict(lambda: 0)
for row in c.execute('select term_text_alphanum from term '):
	d2 = {}
	for c in row[0]:
		if c not in d2:
			d[c] += 1
			d2[c] = True
chrs = sorted((v, k, ord(k)) for k, v in d.items())
pp(chrs)
ordchrs = list(reversed([ordchr for cnt, ch, ordchr in chrs[-TOP_CHRS:]]))
print(ordchrs)
for ordchr in ordchrs:
	print('chr_%s_count, ' % ordchr, end='')

for ordchr in ordchrs:
	print('chr_%s_count integer, ' % ordchr, end='')
	
print 

