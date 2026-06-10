from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.deps import get_db
from app.schemas.run import RunFinish, RunResponse, RunStart
from app.services.auth_service import get_current_user
from app.services.run_service import RunService

router = APIRouter()


@router.get("", response_model=list[RunResponse])
def list_runs(
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[RunResponse]:
    service = RunService(db)
    runs = service.list_runs(current_user.id)
    return [RunResponse.model_validate(run) for run in runs]


@router.post("/start", response_model=RunResponse, status_code=201)
def start_run(
    payload: RunStart,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RunResponse:
    service = RunService(db)
    run = service.start_run(current_user, payload)
    return RunResponse.model_validate(run)


@router.get("/{run_id}", response_model=RunResponse)
def get_run(
    run_id: int,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RunResponse:
    service = RunService(db)
    run = service.get_run(run_id, current_user.id)
    return RunResponse.model_validate(run)


@router.post("/{run_id}/finish", response_model=RunResponse)
def finish_run(
    run_id: int,
    payload: RunFinish,
    current_user=Depends(get_current_user),
    db: Session = Depends(get_db),
) -> RunResponse:
    service = RunService(db)
    run = service.finish_run(run_id, current_user, payload)
    return RunResponse.model_validate(run)
