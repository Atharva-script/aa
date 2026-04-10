import sys
sys.path.insert(0, 'components')
import test8
test8.setup_nltk_and_model()

# Test Hindi words as they would come from Google STT (hi-IN)
hindi_tests = [
    ('madarchod', 'hi'),
    ('chutiya', 'hi'),
    ('gaand', 'hi'),
    ('harami', 'hi'),
    ('randi', 'hi'),
    ('behenchod', 'hi'),
    ('saala kutta', 'hi'),
    ('lund', 'hi'),
    ('gandu', 'hi'),
    ('maar da chod', 'hi'),   # phonetic variant
    ('teri maa ki chut', 'hi'),
    ('bhosadi ke', 'hi'),
    ('kamine', 'hi'),
    ('haramzada', 'hi'),
    ('balatkar', 'hi'),
]

print('\n--- Hindi Detection Test ---')
for word, lang in hindi_tests:
    label, is_bullying, score, _, matched = test8.predict_toxicity(word, lang=lang)
    status = '!!! DETECTED' if is_bullying else '    NOT detected'
    print(f'{status}: [{lang}] "{word}" -> {label} matched={matched}')
