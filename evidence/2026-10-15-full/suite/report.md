| Check | Passed | Score | Time | Note |
|---|---:|---:|---:|---|
| drafts | 12/12 | 100.0% | 20s | drafted 140 tok/s vs undrafted 143 tok/s |
| concurrent | 12/12 | 100.0% | 20s | 4 streams together vs alone |
| streaming | 4/4 | 100.0% | 7s | identical |
| multiturn | 8/8 | 100.0% | 3s | recalled 8/8 facts |
| stop | 3/3 | 100.0% | 0s | 3/3 stopped before the string |
| thinking | 10/10 | 100.0% | 18s | 0 replies without reasoning_content, 0 with think tags in content |
| copy | 2/2 | 100.0% | 1s | 2/2 byte-identical |
| max-tokens | 3/3 | 100.0% | 0s | 3/3 exact |
| tools | 58/60 | 96.7% | 23s | 'Set a timer for 5 minutes.': got [('set_timer', {'seconds': 300, 'label': '5 minutes'})] |
| json | 30/30 | 100.0% | 7s | all valid |
| ifeval | 120/150 | 80.0% | 377s | loose 120/150, strict 114/150, 150 covered prompts |
| gsm8k | 241/250 | 96.4% | 233s | misses at [12, 37, 89, 102, 119, 147, 163, 182, 187] |
| mgsm | 190/240 | 79.2% | 355s | de 27/30, es 29/30, fr 27/30, ja 26/30, zh 27/30, ru 28/30, sw 9/30, bn 17/30 |
| mmlu | 279/342 | 81.6% | 211s | 57 subjects x 6; weakest global_facts 2/6, virology 2/6, college_chemistry 3/6 |
| humaneval | 153/164 | 93.3% | 241s | pass@1 greedy; failed ['HumanEval_115', 'HumanEval_118', 'HumanEval_120', 'HumanEval_132', 'HumanEval_145', 'HumanEval_147'] ... |
| repetition | 8/8 | 100.0% | 46s | repeated 4-grams 0.37% mean, max 1.24%; 0 replies hit max_tokens |
| long-context | 55/55 | 100.0% | 331s | needles 15/15 to 222k, facts 10/10@28k, 10/10@56k, 10/10@113k, 10/10@223k, slowest prefill 4504 tok/s |
| vision | 12/12 | 100.0% | 1s | all probes answered |
| soak | 60/60 | 100.0% | 89s | 3 chats x 20 turns at once beside a decoding stream (5.5k-6.2k-token prompts): 60/60 equal to the same request alone, 0 errors, server answers after; 60/60 concurrent turns resumed a kept state |
| snapshot | 12/12 | 100.0% | 10s | replies written to /storage/recipe-harness/runs/nemotron-bolt-5090/20261015-175621-full/suite/replies.json |
