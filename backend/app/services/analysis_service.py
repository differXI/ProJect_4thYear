from __future__ import annotations

import json
import re
import traceback
from dataclasses import dataclass

import httpx

from app.core.config import settings


@dataclass
class AnalysisResult:
    insight: str
    reasoning: str
    recommendations: list[str]


class GeminiUnavailableError(Exception):
    pass


_GEMINI_MODELS = (
    "gemini-2.5-flash",       # v1beta
    "gemini-2.5-flash-lite",  # v1beta  
    "gemini-2.0-flash",       # v1
    "gemini-2.0-flash-lite",  # v1
)

_MODEL_API_VERSION = {
    "gemini-2.5-flash": "v1beta",
    "gemini-2.5-flash-lite": "v1beta",
    "gemini-2.0-flash": "v1",
    "gemini-2.0-flash-lite": "v1",
}


class AnalysisService:

    def analyze(
        self,
        *,
        distance_km: float,
        duration_seconds: int,
        step_count: int,
        avg_pace_min_per_km: float | None,
        recent_runs: list[dict],
    ) -> AnalysisResult:

        if not settings.gemini_api_key:
            raise GeminiUnavailableError("Missing GEMINI_API_KEY")

        summary = self._build_structured_summary(
            distance_km=distance_km,
            duration_seconds=duration_seconds,
            step_count=step_count,
            avg_pace_min_per_km=avg_pace_min_per_km,
            recent_runs=recent_runs,
        )

        return self._call_gemini(summary)

    def _build_structured_summary(
        self,
        *,
        distance_km: float,
        duration_seconds: int,
        step_count: int,
        avg_pace_min_per_km: float | None,
        recent_runs: list[dict],
    ) -> dict:

        pace = (
            (duration_seconds / 60) / distance_km
            if avg_pace_min_per_km is None and distance_km > 0
            else (avg_pace_min_per_km or 0)
        )

        recent_paces = [
            run["avg_pace_min_per_km"]
            for run in recent_runs
            if run.get("avg_pace_min_per_km") is not None
        ]

        avg_recent_pace = (
            sum(recent_paces) / len(recent_paces)
            if recent_paces
            else None
        )

        pace_delta = (
            round(pace - avg_recent_pace, 2)
            if avg_recent_pace is not None
            else 0
        )

        cadence = (
            round(step_count / (duration_seconds / 60))
            if duration_seconds > 0
            else 0
        )

        return {
            "distance_km": round(distance_km, 2),
            "duration_minutes": round(duration_seconds / 60, 1),
            "step_count": step_count,
            "avg_pace_min_per_km": round(pace, 2),
            "cadence_spm": cadence,
            "recent_run_count": len(recent_runs),
            "pace_delta_vs_recent": pace_delta,
        }

    def _call_gemini(self, data: dict) -> AnalysisResult:

        prompt = f"""
You are an experienced running coach.

Analyze the run data.

IMPORTANT RULES:

1. Return ONLY JSON
2. No markdown
3. No explanations
4. No code block
5. Output must be valid JSON

JSON format:

{{
  "insight": "string",
  "reasoning": "string",
  "recommendations": [
    "string",
    "string",
    "string"
  ]
}}

Language: English

RUN DATA:

{json.dumps(data, ensure_ascii=False)}
"""

        payload = {
            "contents": [
                {
                    "parts": [
                        {
                            "text": prompt
                        }
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0.4,
                "maxOutputTokens": 1024
            }
        }

        last_error = None

        for model in _GEMINI_MODELS:

            try:

                version = _MODEL_API_VERSION.get(model, "v1beta")
                url = (
                     f"https://generativelanguage.googleapis.com/"
                      f"{version}/models/{model}:generateContent"
                )

                response = httpx.post(
                    f"{url}?key={settings.gemini_api_key}",
                    json=payload,
                    timeout=30,
                )

                if response.status_code != 200:
                    print(
                        f"[GEMINI ERROR {model}]",
                        response.status_code,
                        response.text,
                    )
                    last_error = response.text
                    continue

                body = response.json()

                candidates = body.get("candidates")

                if not candidates:
                    raise ValueError("No candidates returned")

                text = (
                    candidates[0]
                    .get("content", {})
                    .get("parts", [{}])[0]
                    .get("text", "")
                )

                parsed = self._parse_json_response(text)

                insight = str(
                    parsed.get("insight", "")
                ).strip()

                reasoning = str(
                    parsed.get("reasoning", "")
                ).strip()

                recommendations = parsed.get(
                    "recommendations",
                    [],
                )

                if isinstance(recommendations, str):
                    recommendations = [recommendations]

                recommendations = [
                    str(item).strip()
                    for item in recommendations
                    if str(item).strip()
                ]

                if not insight:
                    raise ValueError(
                        "Empty insight returned"
                    )

                return AnalysisResult(
                    insight=insight,
                    reasoning=reasoning,
                    recommendations=recommendations,
                )

            except Exception as exc:
                traceback.print_exc()
                last_error = str(exc)

        raise GeminiUnavailableError(
            last_error or "Gemini call failed"
        )

    @staticmethod
    def _parse_json_response(text: str) -> dict:

        text = text.strip()

        match = re.search(
            r"```(?:json)?\s*(.*?)```",
            text,
            re.DOTALL,
        )

        if match:
            text = match.group(1).strip()

        try:
            return json.loads(text)

        except Exception:

            start = text.find("{")
            end = text.rfind("}")

            if start >= 0 and end > start:
                return json.loads(
                    text[start:end + 1]
                )

            raise ValueError(
                f"Invalid JSON returned:\n{text}"
            )