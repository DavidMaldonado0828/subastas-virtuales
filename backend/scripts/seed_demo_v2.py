"""Carga un segundo conjunto de datos de demostración, independiente del V1.

Ejecutar desde backend con ``python -m scripts.seed_demo_v2``.
El modo ``--reset`` solicita escribir ``BORRAR DEMO V2`` antes de borrar
únicamente los registros identificados por el marcador V2.
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.db.session import SessionLocal
from app.models.auction import Auction
from app.models.bid import Bid
from app.models.category import Category
from app.models.product import Product
from app.models.status import Status, StatusApplicability
from app.models.status_history import StatusHistory
from app.models.user import User

PRODUCT_MARKER = "DEMO_SEED_DEMO_V2:"
RESET_PHRASE = "BORRAR DEMO V2"


@dataclass(frozen=True)
class DemoAuction:
    key: str
    product_name: str
    category_name: str
    seller_alias: str
    brand: str
    description: str
    base_price: Decimal
    increment: Decimal
    status: str
    start_offset: timedelta
    end_offset: timedelta
    bid_count: int = 0
    first_bidder: int = 0


DEMO_AUCTIONS = (
    DemoAuction("active_console", "Consola retro de videojuegos", "Electrónica", "carlos_antiguedades", "Pixel Norte", "Consola retro revisada, con controles originales y funcionamiento comprobado.", Decimal("480000.00"), Decimal("25000.00"), "ACTIVA", timedelta(hours=-1), timedelta(hours=6), 4, 0),
    DemoAuction("active_watercolor", "Acuarela de paisaje cafetero", "Arte", "carlos_antiguedades", "Taller La Montaña", "Acuarela original de un paisaje cafetero, firmada y enmarcada para exhibición.", Decimal("320000.00"), Decimal("20000.00"), "ACTIVA", timedelta(hours=-1), timedelta(hours=9)),
    DemoAuction("active_ring", "Anillo de plata con esmeralda", "Joyería", "laura_vintage", "Esmeraldas del Valle", "Anillo artesanal en plata de ley con esmeralda natural engastada.", Decimal("690000.00"), Decimal("30000.00"), "ACTIVA", timedelta(hours=-1), timedelta(hours=14), 5, 1),
    DemoAuction("active_tea", "Juego de té de porcelana", "Hogar", "laura_vintage", "Porcelanas Santa Clara", "Juego de té de porcelana pintado a mano, compuesto por tetera y seis puestos.", Decimal("410000.00"), Decimal("25000.00"), "ACTIVA", timedelta(hours=-1), timedelta(hours=22), 6, 2),
    DemoAuction("scheduled_guitar", "Guitarra acústica de estudio", "Instrumentos musicales", "laura_vintage", "Sonora Andina", "Guitarra acústica de estudio con acabado natural, cuerdas nuevas y estuche blando.", Decimal("750000.00"), Decimal("40000.00"), "PROGRAMADA", timedelta(hours=2), timedelta(hours=26)),
    DemoAuction("scheduled_stamps", "Álbum de estampillas antiguas", "Coleccionables", "carlos_antiguedades", "Filatelia Central", "Álbum organizado de estampillas antiguas colombianas y latinoamericanas.", Decimal("260000.00"), Decimal("15000.00"), "PROGRAMADA", timedelta(hours=24), timedelta(hours=48)),
    DemoAuction("closed_bag", "Bolso de cuero vintage", "Moda y accesorios", "carlos_antiguedades", "Cuero del Centro", "Bolso vintage de cuero genuino restaurado, con herrajes originales en buen estado.", Decimal("380000.00"), Decimal("20000.00"), "CERRADA", timedelta(days=-5), timedelta(days=-4), 4, 3),
    DemoAuction("no_winner_ball", "Balón de fútbol firmado", "Deportes", "laura_vintage", "Cancha de Leyenda", "Balón conmemorativo firmado, conservado en vitrina y sin uso deportivo.", Decimal("520000.00"), Decimal("30000.00"), "FINALIZADA_SIN_GANADOR", timedelta(days=-3), timedelta(days=-2)),
)

REQUIRED_ROLES = {
    "carlos_antiguedades": UserRole.VENDEDOR,
    "laura_vintage": UserRole.VENDEDOR,
    "mafe_gomez": UserRole.POSTOR,
    "juanse_mtz": UserRole.POSTOR,
    "David23": UserRole.POSTOR,
    "pedro_pujas": UserRole.POSTOR,
    "sofia_art": UserRole.POSTOR,
    "admin_subastas": UserRole.ADMIN,
}


def _required_users(session: Session) -> dict[str, User] | None:
    users = session.scalars(select(User).where(User.alias.in_(list(REQUIRED_ROLES)))).all()
    by_alias = {user.alias: user for user in users}
    issues = []
    for alias, role in REQUIRED_ROLES.items():
        user = by_alias.get(alias)
        if user is None:
            issues.append(f"falta {alias} ({role.value})")
        elif user.role != role:
            issues.append(f"{alias} debe tener rol {role.value}")
    if issues:
        print("No se cargó el demo V2: " + "; ".join(issues) + ". No se modificó ningún registro.", file=sys.stderr)
        return None
    return by_alias


def _required_categories(session: Session) -> dict[str, Category] | None:
    names = sorted({demo.category_name for demo in DEMO_AUCTIONS})
    categories = session.scalars(select(Category).where(Category.name.in_(names))).all()
    by_name = {category.name: category for category in categories}
    active_status = session.scalar(select(Status.status_id).where(Status.code == "ACTIVO"))
    issues = []
    for name in names:
        category = by_name.get(name)
        if category is None:
            issues.append(f"falta la categoría {name}")
        elif category.status_id != active_status:
            issues.append(f"la categoría {name} no está ACTIVA")
    if issues:
        print("No se cargó el demo V2: " + "; ".join(issues) + ". No se modificó ningún registro.", file=sys.stderr)
        return None
    return by_name


def _status_id(session: Session, code: str, entity_type: str) -> int | None:
    return session.scalar(
        select(Status.status_id).join(StatusApplicability, StatusApplicability.status_id == Status.status_id)
        .where(Status.code == code, StatusApplicability.entity_type == entity_type)
    )


def _add_history(session: Session, *, entity_type: str, entity_id: int,
                 old_status: str | None, new_status: str, changed_by: int | None,
                 source: str, changed_at: datetime) -> StatusHistory:
    entry = StatusHistory(entity_type=entity_type, entity_id=entity_id,
        old_status_code=old_status, new_status_code=new_status, changed_by=changed_by,
        event_source=source, changed_at=changed_at)
    session.add(entry)
    return entry


def _bid_specs(demo: DemoAuction, auction: Auction, postors: list[User]):
    for number in range(demo.bid_count):
        participant = postors[(demo.first_bidder + number) % len(postors)]
        amount = demo.base_price + demo.increment * number
        yield participant.user_id, amount, auction.start_date + timedelta(minutes=number + 1)


def _initial_product_history(session: Session, product: Product) -> StatusHistory | None:
    return session.scalar(select(StatusHistory).where(
        StatusHistory.entity_type == "PRODUCT", StatusHistory.entity_id == product.product_id,
        StatusHistory.old_status_code.is_(None), StatusHistory.new_status_code == "ACTIVO",
        StatusHistory.changed_by == product.seller_id, StatusHistory.event_source == "USER",
        StatusHistory.changed_at == product.created_at))


def _initial_auction_history(session: Session, auction: Auction, seller_id: int) -> StatusHistory | None:
    return session.scalar(select(StatusHistory).where(
        StatusHistory.entity_type == "AUCTION", StatusHistory.entity_id == auction.auction_id,
        StatusHistory.old_status_code.is_(None), StatusHistory.new_status_code == "PROGRAMADA",
        StatusHistory.changed_by == seller_id, StatusHistory.event_source == "USER",
        StatusHistory.changed_at == auction.created_at))


def _seed(session: Session, users: dict[str, User], categories: dict[str, Category]) -> tuple[int, int]:
    status_ids = {
        (code, entity): _status_id(session, code, entity)
        for entity, codes in {"PRODUCT": ("ACTIVO",), "AUCTION": ("PROGRAMADA", "ACTIVA", "CERRADA", "FINALIZADA_SIN_GANADOR")}.items()
        for code in codes
    }
    missing = [f"{code}/{entity}" for (code, entity), value in status_ids.items() if value is None]
    if missing:
        raise RuntimeError("Faltan estados requeridos: " + ", ".join(missing))

    postors = [users[alias] for alias in ("mafe_gomez", "juanse_mtz", "David23", "pedro_pujas", "sofia_art")]
    names = [demo.product_name for demo in DEMO_AUCTIONS]
    existing = {product.name: product for product in session.scalars(select(Product).where(Product.name.in_(names))).all()}
    now = datetime.now(UTC)
    products_created = auctions_created = 0

    for demo in DEMO_AUCTIONS:
        seller = users[demo.seller_alias]
        product = existing.get(demo.product_name)
        if product is not None:
            if product.seller_id != seller.user_id or not product.description.startswith(PRODUCT_MARKER):
                print(f"Se conserva el producto existente con nombre reservado: {demo.product_name}", file=sys.stderr)
                continue
            if session.scalar(select(Status.code).where(Status.status_id == product.status_id)) != "ACTIVO":
                print(f"Se conserva el producto V2 que ya no está ACTIVO: {demo.product_name}", file=sys.stderr)
                continue
            auctions = session.scalars(select(Auction).where(Auction.product_id == product.product_id)).all()
            own = next((row for row in auctions if row.created_at == product.created_at + timedelta(seconds=10)), None)
            if own is not None and _initial_auction_history(session, own, seller.user_id) is not None:
                continue
            if own is not None or auctions:
                print(f"Se conserva el producto que tiene una subasta ajena o incompleta: {demo.product_name}", file=sys.stderr)
                continue
            product_created_at = product.created_at
        else:
            start_date = now + demo.start_offset
            product_created_at = min(now - timedelta(minutes=1), start_date - timedelta(minutes=30))
            product = Product(seller_id=seller.user_id, category_id=categories[demo.category_name].category_id,
                status_id=status_ids[("ACTIVO", "PRODUCT")], name=demo.product_name, brand=demo.brand,
                description=f"{PRODUCT_MARKER} {demo.description}", image_url=None, created_at=product_created_at)
            session.add(product)
            session.flush()
            _add_history(session, entity_type="PRODUCT", entity_id=product.product_id,
                old_status=None, new_status="ACTIVO", changed_by=seller.user_id,
                source="USER", changed_at=product_created_at)
            existing[product.name] = product
            products_created += 1

        start_date = now + demo.start_offset
        end_date = now + demo.end_offset
        created_at = product_created_at + timedelta(seconds=10)
        auction = Auction(product_id=product.product_id, status_id=status_ids[(demo.status, "AUCTION")],
            base_price=demo.base_price, minimum_increment=demo.increment,
            start_date=start_date, end_date=end_date, created_at=created_at)
        session.add(auction)
        session.flush()
        auctions_created += 1
        _add_history(session, entity_type="AUCTION", entity_id=auction.auction_id,
            old_status=None, new_status="PROGRAMADA", changed_by=seller.user_id,
            source="USER", changed_at=created_at)
        if demo.status != "PROGRAMADA":
            _add_history(session, entity_type="AUCTION", entity_id=auction.auction_id,
                old_status="PROGRAMADA", new_status="ACTIVA", changed_by=None,
                source="SCHEDULER", changed_at=start_date)
        if demo.status in {"CERRADA", "FINALIZADA_SIN_GANADOR"}:
            _add_history(session, entity_type="AUCTION", entity_id=auction.auction_id,
                old_status="ACTIVA", new_status=demo.status, changed_by=None,
                source="SCHEDULER", changed_at=end_date)
        for participant_id, amount, bid_date in _bid_specs(demo, auction, postors):
            session.add(Bid(auction_id=auction.auction_id, participant_id=participant_id,
                amount=amount, bid_date=bid_date))

    return products_created, auctions_created


def _expected_history(demo: DemoAuction, auction: Auction, seller_id: int):
    expected = {(None, "PROGRAMADA", seller_id, "USER", auction.created_at)}
    if demo.status != "PROGRAMADA":
        expected.add(("PROGRAMADA", "ACTIVA", None, "SCHEDULER", auction.start_date))
    if demo.status in {"CERRADA", "FINALIZADA_SIN_GANADOR"}:
        expected.add(("ACTIVA", demo.status, None, "SCHEDULER", auction.end_date))
    return expected


def _reset(session: Session, users: dict[str, User]) -> tuple[int, int, int, list[str]]:
    names = [demo.product_name for demo in DEMO_AUCTIONS]
    products = session.scalars(select(Product).where(Product.name.in_(names), Product.description.like(f"{PRODUCT_MARKER}%"))).all()
    postors = [users[alias] for alias in ("mafe_gomez", "juanse_mtz", "David23", "pedro_pujas", "sofia_art")]
    removed_products = removed_auctions = removed_bids = 0
    messages: list[str] = []

    for product in products:
        demo = next(item for item in DEMO_AUCTIONS if item.product_name == product.name)
        seller = users[demo.seller_alias]
        if product.seller_id != seller.user_id or product.updated_at is not None:
            messages.append(f"Se conserva {product.name}: no coincide con el propietario del seed o fue editado.")
            continue
        product_history = _initial_product_history(session, product)
        histories = session.scalars(select(StatusHistory).where(
            StatusHistory.entity_type == "PRODUCT", StatusHistory.entity_id == product.product_id)).all()
        if product_history is None or len(histories) != 1:
            messages.append(f"Se conserva {product.name}: su historial de producto no coincide con el seed.")
            continue

        auctions = session.scalars(select(Auction).where(Auction.product_id == product.product_id)).all()
        own = next((row for row in auctions if row.created_at == product.created_at + timedelta(seconds=10)), None)
        if own is None:
            if auctions:
                messages.append(f"Se conserva {product.name}: solo tiene subastas ajenas al seed.")
                continue
            session.delete(product_history)
            session.delete(product)
            session.flush()
            removed_products += 1
            continue

        auction_history = session.scalars(select(StatusHistory).where(
            StatusHistory.entity_type == "AUCTION", StatusHistory.entity_id == own.auction_id)).all()
        initial = _initial_auction_history(session, own, seller.user_id)
        expected_history = _expected_history(demo, own, seller.user_id)
        if initial is None or any((row.old_status_code, row.new_status_code, row.changed_by,
                                   row.event_source, row.changed_at) not in expected_history for row in auction_history):
            messages.append(f"Se conserva {product.name}: el historial de subasta contiene datos no atribuibles al seed.")
            continue
        expected_bids = list(_bid_specs(demo, own, postors))
        bids = session.scalars(select(Bid).where(Bid.auction_id == own.auction_id)).all()
        actual_bids = [(row.participant_id, row.amount, row.bid_date) for row in bids]
        if sorted(actual_bids, key=str) != sorted(expected_bids, key=str):
            messages.append(f"Se conserva {product.name}: las pujas no coinciden exactamente con el seed.")
            continue

        for bid in bids:
            session.delete(bid)
            removed_bids += 1
        for row in auction_history:
            session.delete(row)
        session.delete(own)
        session.flush()
        removed_auctions += 1
        if any(row.auction_id != own.auction_id for row in auctions):
            messages.append(f"Se conserva {product.name}: tiene otra subasta ajena al seed.")
            continue
        session.delete(product_history)
        session.delete(product)
        session.flush()
        removed_products += 1

    return removed_products, removed_auctions, removed_bids, messages


def main() -> int:
    parser = argparse.ArgumentParser(description="Carga o restablece los datos demo V2 sin tocar los del V1.")
    parser.add_argument("--reset", action="store_true", help="elimina únicamente registros atribuibles al seed V2")
    args = parser.parse_args()
    if args.reset:
        try:
            answer = input(f'Para confirmar el reset V2, escribe exactamente "{RESET_PHRASE}": ').strip()
        except (EOFError, KeyboardInterrupt):
            print("Reset V2 cancelado; no se modificó la base de datos.")
            return 1
        if answer != RESET_PHRASE:
            print("Confirmación incorrecta; no se modificó la base de datos.")
            return 1

    try:
        with SessionLocal() as session:
            users = _required_users(session)
            if users is None:
                return 2
            if args.reset:
                products, auctions, bids, messages = _reset(session, users)
                session.commit()
                print(f"Reset V2 completado: productos={products}, subastas={auctions}, pujas={bids}.")
                for message in messages:
                    print(message)
                return 0
            categories = _required_categories(session)
            if categories is None:
                return 2
            products, auctions = _seed(session, users, categories)
            session.commit()
            print(f"Seed demo V2 completado: productos nuevos={products}, subastas nuevas={auctions}; datos V1 conservados.")
        return 0
    except Exception as exc:
        print(f"No se pudo completar seed_demo_v2 ({type(exc).__name__}).", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
