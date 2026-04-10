import concurrent.futures
import time
import threading


class DetectorQueue:
    """Asynchronous wrapper around a synchronous detector.

    - detector: object with `classify(text)` -> (label, score, latency_ms)
    - max_workers: thread pool size
    - callback: function called as callback(result_dict) when detection completes

    Result dict contains: {
        'text': text,
        'label': label,
        'score': score,
        'latency_ms': latency_ms,
        'meta': meta
    }
    """

    def __init__(self, detector, max_workers=2, callback=None):
        self.detector = detector
        self.callback = callback
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=max_workers)
        self.lock = threading.Lock()

    def enqueue(self, text, meta=None):
        future = self.executor.submit(self._run_detection, text, meta)
        future.add_done_callback(self._done_cb)
        return future

    def _run_detection(self, text, meta):
        start = time.perf_counter()
        label, score, latency_ms = self.detector.classify(text)
        end = time.perf_counter()
        wall_ms = (end - start) * 1000.0
        return {'text': text, 'label': label, 'score': score, 'latency_ms': latency_ms, 'wall_ms': wall_ms, 'meta': meta}

    def _done_cb(self, future):
        try:
            res = future.result()
            if self.callback:
                try:
                    self.callback(res)
                except Exception:
                    pass
        except Exception:
            pass

    def shutdown(self, wait=True):
        self.executor.shutdown(wait=wait)
