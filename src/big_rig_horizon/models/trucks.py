"""Truck catalog and garage upgrades.

Upgrades and the chosen truck live on the player profile; they come together
in :func:`build_truck_specs`, which produces the :class:`TruckSpecs` the
driving simulation runs on.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
import json
import sys
from pathlib import Path

from ..sim.vehicle import TruckSpecs

# Upgrade effect constants.
ENGINE_TUNE_TORQUE_PER_TIER = 0.10   # +10% torque per tier
AERO_DRAG_MULT = 0.88                # -12% drag
TANK_EXTRA_GAL = 50.0
BRAKE_FADE_BONUS_C = 150.0           # fade onset pushed this much hotter


@dataclass(frozen=True)
class TruckModel:
    key: str
    label: str
    price: float
    description: str
    specs: TruckSpecs


def _get_hardcoded_defaults() -> dict[str, TruckModel]:
    return {
        "rig": TruckModel(
            "rig", "standard rig", 0.0,
            "The dependable tractor you started with. Balanced all around.",
            TruckSpecs()),
        "heavy_hauler": TruckModel(
            "heavy_hauler", "heavy hauler", 52_000.0,
            "A brute: a quarter more torque and a two hundred gallon tank, but "
            "blunt aerodynamics and a thirstier engine.",
            TruckSpecs(max_torque_nm=3_000.0, fuel_tank_gal=200.0,
                       drag_coefficient=0.75, fuel_burn_factor=1.2,
                       mass_kg=37_500.0)),
        "fuel_saver": TruckModel(
            "fuel_saver", "fuel saver", 45_000.0,
            "An aerodynamic cruiser built for fuel efficiency and long highway runs. Reduced power but superb range.",
            TruckSpecs(drag_coefficient=0.52, fuel_burn_factor=0.8,
                       max_torque_nm=2_100.0, fuel_tank_gal=160.0,
                       mass_kg=34_000.0)),
        "mountain_climber": TruckModel(
            "mountain_climber", "mountain climber", 68_000.0,
            "Equipped with a massive high-displacement engine to climb steep grades with ease. Heavy fuel burn.",
            TruckSpecs(max_torque_nm=3_600.0, fuel_burn_factor=1.4,
                       drag_coefficient=0.78, fuel_tank_gal=220.0,
                       mass_kg=39_000.0)),
        "road_train_king": TruckModel(
            "road_train_king", "road train king", 85_000.0,
            "A premium multi-axle powerhouse designed for the heaviest loads on the continent.",
            TruckSpecs(max_torque_nm=4_000.0, fuel_burn_factor=1.6,
                       drag_coefficient=0.82, fuel_tank_gal=250.0,
                       mass_kg=42_000.0)),
    }


class TruckCatalog(dict):
    def __init__(self):
        super().__init__()
        self._loaded = False

    def _ensure_loaded(self):
        if not self._loaded:
            self._loaded = True
            catalog = {}
            # Locate internal data folder
            td = Path(__file__).resolve().parent.parent / "data" / "trucks"
            if td.exists():
                for file in td.glob("*.json"):
                    try:
                        with open(file, "r", encoding="utf-8") as f:
                            data = json.load(f)
                        key = data["key"]
                        label = data["label"]
                        price = float(data["price"])
                        description = data["description"]
                        
                        specs_dict = data.get("specs", {})
                        valid_fields = TruckSpecs.__dataclass_fields__.keys()
                        filtered_specs = {k: v for k, v in specs_dict.items() if k in valid_fields}
                        specs = TruckSpecs(**filtered_specs)
                        
                        catalog[key] = TruckModel(key, label, price, description, specs)
                    except Exception as e:
                        print(f"Error loading truck file {file}: {e}", file=sys.stderr)
            
            if not catalog:
                catalog = _get_hardcoded_defaults()
            self.clear()
            self.update(catalog)

    def __getitem__(self, key):
        self._ensure_loaded()
        return super().__getitem__(key)

    def get(self, key, default=None):
        self._ensure_loaded()
        return super().get(key, default)

    def values(self):
        self._ensure_loaded()
        return super().values()

    def keys(self):
        self._ensure_loaded()
        return super().keys()

    def items(self):
        self._ensure_loaded()
        return super().items()

    def __contains__(self, key):
        self._ensure_loaded()
        return super().__contains__(key)

    def __len__(self):
        self._ensure_loaded()
        return super().__len__()


TRUCK_CATALOG = TruckCatalog()


@dataclass(frozen=True)
class Upgrade:
    key: str
    label: str
    description: str
    prices: tuple[float, ...]      # one entry per tier

    @property
    def max_tier(self) -> int:
        return len(self.prices)


UPGRADE_CATALOG: dict[str, Upgrade] = {
    "engine_tune": Upgrade(
        "engine_tune", "Engine tune",
        "Ten percent more torque per tier. Two tiers available.",
        (12_000.0, 26_000.0)),
    "aero_kit": Upgrade(
        "aero_kit", "Aerodynamic kit",
        "Roof fairing and side skirts cut drag twelve percent, "
        "saving fuel at highway speed.",
        (9_000.0,)),
    "long_range_tank": Upgrade(
        "long_range_tank", "Long-range tank",
        "Adds fifty gallons of fuel capacity.",
        (7_500.0,)),
    "reinforced_brakes": Upgrade(
        "reinforced_brakes", "Reinforced brakes",
        "High-temperature linings resist brake fade on long descents.",
        (6_500.0,)),
}


def build_truck_specs(truck_key: str, upgrades: dict[str, int]) -> TruckSpecs:
    """Specs for the given truck model with the profile's upgrades applied."""
    model = TRUCK_CATALOG.get(truck_key, TRUCK_CATALOG["rig"])
    specs = model.specs
    changes: dict[str, float] = {}
    tier = upgrades.get("engine_tune", 0)
    if tier:
        changes["max_torque_nm"] = specs.max_torque_nm * (
            1.0 + ENGINE_TUNE_TORQUE_PER_TIER * min(tier, 2))
    if upgrades.get("aero_kit"):
        changes["drag_coefficient"] = specs.drag_coefficient * AERO_DRAG_MULT
    if upgrades.get("long_range_tank"):
        changes["fuel_tank_gal"] = specs.fuel_tank_gal + TANK_EXTRA_GAL
    if upgrades.get("reinforced_brakes"):
        changes["brake_fade_temp_c"] = specs.brake_fade_temp_c + BRAKE_FADE_BONUS_C
    return replace(specs, **changes) if changes else specs
