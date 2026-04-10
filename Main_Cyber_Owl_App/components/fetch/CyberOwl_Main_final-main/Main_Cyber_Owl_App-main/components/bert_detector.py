from transformers import pipeline
import time
import traceback
from langdetect import detect, DetectorFactory


DetectorFactory.seed = 0


class BertDetector:
    """Robust multilingual detector that tries a sequence of zero-shot models.

    Behavior:
    - Tries models in `try_models` order until a working pipeline is created.
    - Logs detailed errors to `bert_init.log` when initialization fails.
    - `classify` returns (label, score, latency_ms). If the pipeline is unavailable
      it raises an exception to let caller fall back to keyword checks.
    """

    def __init__(self, try_models=None, candidate_labels=None, prefer_fast=False, device="cpu"):
        # prefer_fast: if True, try smaller/faster models first to reduce latency
        slow_models = [
            "joeddav/xlm-roberta-large-xnli",
            "facebook/bart-large-mnli",
        ]
        fast_models = [
            "typeform/distilbert-base-uncased-mnli",
            "typeform/distilbert-base-uncased-mnli-finetuned-sst-2-english"
        ]
        if try_models is not None:
            self.try_models = try_models
        else:
            self.try_models = (fast_models + slow_models) if prefer_fast else (slow_models + fast_models)
        self.candidate_labels = candidate_labels or ["abusive", "non-abusive"]
        self.hypothesis_template = "This text is {}."
        self.pipe = None
        self.model_name = None
        self.device = device
        self._init_pipeline()

    def _init_pipeline(self):
        last_exc = None
        for m in self.try_models:
            try:
                # prefer CPU by default; transformer pipeline will choose device automatically
                self.pipe = pipeline("zero-shot-classification", model=m, device=-1 if self.device == "cpu" else 0)
                self.model_name = m
                return
            except Exception as e:
                last_exc = e
                with open("bert_init.log", "a", encoding="utf-8") as fh:
                    fh.write(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}]: Failed model {m}\n")
                    fh.write(traceback.format_exc())
                    fh.write("\n---\n")
        # If none worked, raise the last exception for visibility
        if last_exc:
            raise last_exc

    def classify(self, text, lang_hint=None):
        """Classify `text` and return normalized label, score, latency_ms.

        Performs a language hint via `langdetect` when helpful (best-effort).
        """
        if not text or not text.strip():
            return "Non-Bullying", 0.0, 0.0

        # best-effort language detect (may raise; ignore failures)
        try:
            if lang_hint is None:
                lang_hint = detect(text)
        except Exception:
            lang_hint = None

        start = time.perf_counter()
        res = self.pipe(text, self.candidate_labels, hypothesis_template=self.hypothesis_template)
        end = time.perf_counter()
        latency_ms = (end - start) * 1000.0

        label = res.get("labels", [None])[0]
        score = res.get("scores", [0.0])[0]

        if label is None:
            return "Non-Bullying", 0.0, latency_ms

        normalized = "Bullying" if label.lower().startswith("abusive") else "Non-Bullying"
        return normalized, float(score), latency_ms
