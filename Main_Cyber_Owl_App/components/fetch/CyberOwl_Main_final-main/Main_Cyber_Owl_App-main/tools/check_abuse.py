from components import test8

# ensure models and abuse lists load
print('Loading models and abuse lists...')
test8.setup_nltk_and_model()

samples = [
    "chutiya",
    "teri maa ki chut",
    "tum chutia ho",
    "you are an idiot",
    "I will not harass anyone here"
]

for s in samples:
    print(s, '->', test8.predict_toxicity(s))
