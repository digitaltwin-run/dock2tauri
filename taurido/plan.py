"""Language-neutral execution plan shared by all Dock2Tauri launchers."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from typing import Dict, Optional, Tuple, Union


PlanValue = Union[str, int, bool, None, Tuple[str, ...]]


@dataclass(frozen=True)
class BuildPlan:
    image_or_dockerfile: str
    host_port: str = "8088"
    container_port: str = "80"
    build: bool = False
    target: Optional[str] = None
    health_url: Optional[str] = None
    timeout: int = 30
    cross: bool = False
    project_root: Optional[str] = None
    export_dir: Optional[str] = None
    app_name: Optional[str] = None
    filename_prefix: Optional[str] = None
    copy_to: Tuple[str, ...] = ()
    launch: bool = False
    list_bundles: bool = False
    debug: bool = False

    def to_dict(self) -> Dict[str, PlanValue]:
        return asdict(self)
