"""Run performance analysis with optional Gemini API."""

from __future__ import annotations

import json
from dataclasses import dataclass

import httpx

from app.core.config import settings


@dataclass
class AnalysisResult:
    insight: str
    reasoning: str
    recommendations: str


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
        structured = self._build_structured_summary(
            distance_km=distance_km,
            duration_seconds=duration_seconds,
            step_count=step_count,
            avg_pace_min_per_km=avg_pace_min_per_km,
            recent_runs=recent_runs,
        )

        if settings.gemini_api_key:
            gemini_result = self._call_gemini(structured)
            if gemini_result is not None:
                return gemini_result

        return self._rule_based_analysis(structured)

    def _build_structured_summary(
        self,
        *,
        distance_km: float,
        duration_seconds: int,
        step_count: int,
        avg_pace_min_per_km: float | None,
        recent_runs: list[dict],
    ) -> dict:
        pace = avg_pace_min_per_km
        if pace is None and distance_km > 0:
            pace = (duration_seconds / 60.0) / distance_km

        recent_paces = [
            item["avg_pace_min_per_km"]
            for item in recent_runs
            if item.get("avg_pace_min_per_km") is not None
        ]
        avg_recent_pace = sum(recent_paces) / len(recent_paces) if recent_paces else None

        pace_delta = None
        if pace is not None and avg_recent_pace is not None:
            pace_delta = round(pace - avg_recent_pace, 2)

        cadence = None
        if duration_seconds > 0 and step_count > 0:
            cadence = round(step_count / (duration_seconds / 60.0), 0)

        return {
            "distance_km": round(distance_km, 2),
            "duration_minutes": round(duration_seconds / 60.0, 1),
            "step_count": step_count,
            "avg_pace_min_per_km": round(pace, 2) if pace is not None else None,
            "cadence_spm": cadence,
            "recent_run_count": len(recent_runs),
            "pace_delta_vs_recent": pace_delta,
        }

    def _rule_based_analysis(self, data: dict) -> AnalysisResult:
        pace = data.get("avg_pace_min_per_km")
        pace_delta = data.get("pace_delta_vs_recent")
        cadence = data.get("cadence_spm")

        if pace is None:
            insight = "Your run was recorded, but pace could not be calculated from the distance."
        elif pace_delta is not None and pace_delta <= -0.3:
            insight = "Strong run. Your pace was faster than your recent average."
        elif pace_delta is not None and pace_delta >= 0.3:
            insight = "This run was slower than your recent average. Recovery or fatigue may be a factor."
        else:
            insight = "Steady performance. Your pace stayed close to your recent average."

        reasoning_parts = [
            f"You covered {data['distance_km']} km in {data['duration_minutes']} minutes.",
        ]
        if pace is not None:
            reasoning_parts.append(f"Average pace was {pace} min/km.")
        if cadence is not None:
            reasoning_parts.append(f"Estimated cadence was about {cadence} steps per minute.")
        if pace_delta is not None:
            direction = "faster" if pace_delta < 0 else "slower"
            reasoning_parts.append(
                f"This was {abs(pace_delta)} min/km {direction} than your recent runs."
            )

        recommendations = []
        if pace is not None and pace > 7.5:
            recommendations.append("Try shorter intervals to gradually improve pace consistency.")
        elif pace is not None:
            recommendations.append("Maintain this pace on your next easy run to build consistency.")
        if cadence is not None and cadence < 150:
            recommendations.append("Focus on shorter, quicker steps to improve cadence.")
        else:
            recommendations.append("Keep hydrating and schedule one recovery day before your next hard run.")

        return AnalysisResult(
            insight=insight,
            reasoning=" ".join(reasoning_parts),
            recommendations=" ".join(recommendations),
        )

    def _call_gemini(self, data: dict) -> AnalysisResult | None:
        prompt = (
            "You are a running coach. Analyze this run data and respond ONLY with valid JSON "
            'with keys "insight", "reasoning", and "recommendations". '
            f"Run data: {json.dumps(data)}"
        )
        url = (
            "https://generativelanguage.googleapis.com/v1beta/models/"
            f"gemini-2.0-flash:generateContent?key={settings.gemini_api_key}"
        )
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.4},
        }

        try:
            with httpx.Client(timeout=20.0) as client:
                response = client.post(url, json=payload)
                response.raise_for_status()
                body = response.json()
                text = body["candidates"][0]["content"]["parts"][0]["text"]
                cleaned = text.strip()
                if cleaned.startswith("```"):
                    cleaned = cleaned.split("\n", 1)[1]
                    cleaned = cleaned.rsplit("```", 1)[0]
                parsed = json.loads(cleaned)
                return AnalysisResult(
                    insight=str(parsed.get("insight", "")),
                    reasoning=str(parsed.get("reasoning", "")),
                    recommendations=str(parsed.get("recommendations", "")),
                )
        except Exception:
            return None
