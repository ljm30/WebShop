import sys
import json
from tqdm import tqdm
sys.path.insert(0, '../')

from web_agent_site.utils import DEFAULT_FILE_PATH
from web_agent_site.engine.engine import load_products

print(f"Loading products from {DEFAULT_FILE_PATH}...")
all_products, *_ = load_products(filepath=DEFAULT_FILE_PATH)

print(f"Converting {len(all_products)} products to search engine format...")
docs = []
for p in tqdm(all_products, total=len(all_products)):
    option_texts = []
    options = p.get('options', {})
    for option_name, option_contents in options.items():
        option_contents_text = ', '.join(option_contents)
        option_texts.append(f'{option_name}: {option_contents_text}')
    option_text = ', and '.join(option_texts)

    doc = dict()
    doc['id'] = p['asin']
    doc['contents'] = ' '.join([
        p['Title'],
        p['Description'],
        p['BulletPoints'][0],
        option_text,
    ]).lower()
    doc['product'] = p
    docs.append(doc)

print(f"Writing {len(docs)} documents to resources/documents.jsonl...")
with open('./resources/documents.jsonl', 'w+') as f:
    for doc in docs:
        f.write(json.dumps(doc) + '\n')

print("Done!")
