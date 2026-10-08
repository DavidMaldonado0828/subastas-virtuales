"""Carga datos de demostración para el vendedor Carlos y tres postores.

Ejecutar desde backend con ``python -m scripts.seed_demo``.
El modo ``--reset`` solicita escribir ``BORRAR DEMO`` antes de borrar datos.
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
from app.models.auction_cancellation import AuctionCancellation
from app.models.bid import Bid
from app.models.category import Category
from app.models.product import Product
from app.models.status import Status, StatusApplicability
from app.models.status_history import StatusHistory
from app.models.user import User


PRODUCT_MARKER = "DEMO_SEED_DEMO_V1:"
PRODUCT_CATEGORY = "Antigüedades"
RESET_PHRASE = "BORRAR DEMO"
CANCEL_REASON = (
    "Se detectó una discrepancia entre la descripción publicada y el artículo "
    "verificado; se cancela para validar la información del lote."
)


@dataclass(frozen=True)
class DemoAuction:
    key: str
    product_name: str
    brand: str
    description: str
    base_price: Decimal
    increment: Decimal
    status: str
    start_offset: timedelta
    end_offset: timedelta
    bid_count: int = 0
    first_bidder: int = 0
    cancellation_reason: str | None = None


DEMO_AUCTIONS = (
    DemoAuction("active_20h", "DEMO | Reloj de bolsillo dorado", "El Cronista", "Reloj antiguo de bolsillo, pieza demostrativa para catálogo.", Decimal("350000.00"), Decimal("25000.00"), "ACTIVA", timedelta(hours=-1), timedelta(hours=20), 4, 0),
    DemoAuction("active_8h", "DEMO | Jarrón de porcelana azul", "Casa Herencia", "Jarrón de porcelana decorado a mano, pieza demostrativa.", Decimal("280000.00"), Decimal("20000.00"), "ACTIVA", timedelta(hours=-1), timedelta(hours=8), 3, 1),
    DemoAuction("active_5h", "DEMO | Cámara análoga clásica", "Lente Antiguo", "Cámara análoga clásica en buen estado, pieza demostrativa.", Decimal("420000.00"), Decimal("30000.00"), "ACTIVA", timedelta(hours=-1), timedelta(hours=5)),
    DemoAuction("scheduled_3h", "DEMO | Lámpara de mesa vintage", "Luz de Época", "Lámpara vintage para escritorio, pieza demostrativa.", Decimal("190000.00"), Decimal("15000.00"), "PROGRAMADA", timedelta(hours=3), timedelta(hours=27)),
    DemoAuction("scheduled_26h", "DEMO | Colección de monedas antiguas", "Numis Demo", "Colección numismática demostrativa.", Decimal("600000.00"), Decimal("50000.00"), "PROGRAMADA", timedelta(hours=26), timedelta(hours=50)),
    DemoAuction("closed_winner_1", "DEMO | Baúl de madera tallada", "Maderas de Ayer", "Baúl tallado de época, pieza demostrativa con ganador.", Decimal("500000.00"), Decimal("40000.00"), "CERRADA", timedelta(days=-4), timedelta(days=-3), 4, 0),
    DemoAuction("closed_winner_2", "DEMO | Escultura de bronce", "Taller Centenario", "Escultura de bronce, pieza demostrativa con ganador.", Decimal("850000.00"), Decimal("75000.00"), "CERRADA", timedelta(days=-10), timedelta(days=-9), 3, 1),
    DemoAuction("closed_no_bids", "DEMO | Espejo con marco antiguo", "Marco Real", "Espejo antiguo para mostrar cierre sin ofertas.", Decimal("320000.00"), Decimal("20000.00"), "FINALIZADA_SIN_GANADOR", timedelta(days=-7), timedelta(days=-6)),
    DemoAuction("cancelled", "DEMO | Reloj de sobremesa cancelado", "Tiempo de Ayer", "Reloj de sobremesa, lote de demostración cancelado por revisión.", Decimal("700000.00"), Decimal("50000.00"), "CANCELADA", timedelta(hours=-2), timedelta(days=2), 3, 2, CANCEL_REASON),
)

REQUIRED_ROLES = {
    "carlos_antiguedades": UserRole.VENDEDOR,
    "mafe_gomez": UserRole.POSTOR,
    "juanse_mtz": UserRole.POSTOR,
    "David23": UserRole.POSTOR,
    "admin_subastas": UserRole.ADMIN,
}


def _status_id(session: Session, code: str, entity_type: str) -> int | None:
    return session.scalar(
        select(Status.status_id)
        .join(StatusApplicability, StatusApplicability.status_id == Status.status_id)
        .where(Status.code == code, StatusApplicability.entity_type == entity_type)
    )


def _required_users(session: Session) -> dict[str, User] | None:
    aliases = list(REQUIRED_ROLES)
    users = session.scalars(select(User).where(User.alias.in_(aliases))).all()
    by_alias = {user.alias: user for user in users}
    issues = []
    for alias, expected_role in REQUIRED_ROLES.items():
        user = by_alias.get(alias)
        if user is None:
            issues.append(f"falta {alias} ({expected_role.value})")
        elif user.role != expected_role:
            issues.append(f"{alias} debe tener rol {expected_role.value}")
    if issues:
        print("No se cargó el demo: " + "; ".join(issues) + ". No se creó ningún usuario.", file=sys.stderr)
        return None
    return by_alias


def _add_history(
    session: Session,
    *,
    entity_type: str,
    entity_id: int,
    old_status: str | None,
    new_status: str,
    changed_by: int | None,
    source: str,
    changed_at: datetime,
) -> StatusHistory:
    entry = StatusHistory(
        entity_type=entity_type,
        entity_id=entity_id,
        old_status_code=old_status,
        new_status_code=new_status,
        changed_by=changed_by,
        event_source=source,
        changed_at=changed_at,
    )
    session.add(entry)
    return entry


def _dates(demo: DemoAuction, now: datetime) -> tuple[datetime, datetime]:
    return now + demo.start_offset, now + demo.end_offset


def _bid_specs(demo: DemoAuction, auction: Auction, postors: list[User]):
    for number in range(demo.bid_count):
        participant = postors[(demo.first_bidder + number) % len(postors)]
        amount = demo.base_price + demo.increment * number
        bid_date = auction.start_date + timedelta(minutes=number + 1)
        yield participant.user_id, amount, bid_date


def _product_initial_history(session: Session, product: Product) -> StatusHistory | None:
    return session.scalar(select(StatusHistory).where(
        StatusHistory.entity_type == "PRODUCT",
        StatusHistory.entity_id == product.product_id,
        StatusHistory.old_status_code.is_(None),
        StatusHistory.new_status_code == "ACTIVO",
        StatusHistory.changed_by == product.seller_id,
        StatusHistory.event_source == "USER",
        StatusHistory.changed_at == product.created_at,
    ))


def _auction_initial_history(session: Session, auction: Auction, seller_id: int) -> StatusHistory | None:
    return session.scalar(select(StatusHistory).where(
        StatusHistory.entity_type == "AUCTION",
        StatusHistory.entity_id == auction.auction_id,
        StatusHistory.old_status_code.is_(None),
        StatusHistory.new_status_code == "PROGRAMADA",
        StatusHistory.changed_by == seller_id,
        StatusHistory.event_source == "USER",
        StatusHistory.changed_at == auction.created_at,
    ))


def _seed(session: Session, users: dict[str, User]) -> tuple[int, int]:
    category = session.scalar(select(Category).where(Category.name == PRODUCT_CATEGORY))
    category_status = session.scalar(select(Status.code).where(Status.status_id == category.status_id)) if category else None
    if category is None or category_status != "ACTIVO":
        raise RuntimeError(f'No existe una categoría activa llamada "{PRODUCT_CATEGORY}"; ejecuta primero el seed de usuarios.')

    status_ids = {
        (code, entity): _status_id(session, code, entity)
        for entity, codes in {
            "PRODUCT": ("ACTIVO",),
            "AUCTION": ("PROGRAMADA", "ACTIVA", "CERRADA", "FINALIZADA_SIN_GANADOR", "CANCELADA"),
        }.items()
        for code in codes
    }
    missing_statuses = [f"{code}/{entity}" for (code, entity), value in status_ids.items() if value is None]
    if missing_statuses:
        raise RuntimeError("Faltan estados requeridos: " + ", ".join(missing_statuses))

    seller = users["carlos_antiguedades"]
    postors = [users["mafe_gomez"], users["juanse_mtz"], users["David23"]]
    admin = users["admin_subastas"]
    existing_by_name = {
        product.name: product for product in session.scalars(
            select(Product).where(Product.name.in_([demo.product_name for demo in DEMO_AUCTIONS]))
        ).all()
    }
    now = datetime.now(UTC)
    created_products = 0
    created_auctions = 0

    for index, demo in enumerate(DEMO_AUCTIONS):
        product = existing_by_name.get(demo.product_name)
        if product is not None:
            if product.seller_id != seller.user_id or not product.description.startswith(PRODUCT_MARKER):
                print(f"Se conserva el producto existente con nombre reservado: {demo.product_name}", file=sys.stderr)
                continue
            if session.scalar(select(Status.code).where(Status.status_id == product.status_id)) != "ACTIVO":
                print(f"Se conserva el producto demo que ya no está ACTIVO: {demo.product_name}", file=sys.stderr)
                continue
            product_auctions = session.scalars(select(Auction).where(Auction.product_id == product.product_id)).all()
            demo_auction = next((row for row in product_auctions
                if row.created_at == product.created_at + timedelta(seconds=10)), None)
            if demo_auction is not None and _auction_initial_history(session, demo_auction, seller.user_id) is not None:
                continue
            if demo_auction is not None:
                print(f"Se conserva una subasta con fecha reservada que no tiene el historial de seed: {demo.product_name}", file=sys.stderr)
                continue
            if product_auctions:
                print(f"Se conserva el producto que ya tiene una subasta: {demo.product_name}", file=sys.stderr)
                continue
            product_created_at = product.created_at
        else:
            start_date, _end_date = _dates(demo, now)
            product_created_at = min(now - timedelta(minutes=1), start_date - timedelta(minutes=30))
            product = Product(
                seller_id=seller.user_id,
                category_id=category.category_id,
                status_id=status_ids[("ACTIVO", "PRODUCT")],
                name=demo.product_name,
                brand=demo.brand,
                description=f"{PRODUCT_MARKER} {demo.description}",
                image_url=None,
                created_at=product_created_at,
            )
            session.add(product)
            session.flush()
            _add_history(session, entity_type="PRODUCT", entity_id=product.product_id,
                old_status=None, new_status="ACTIVO", changed_by=seller.user_id,
                source="USER", changed_at=product_created_at)
            existing_by_name[product.name] = product
            created_products += 1

        start_date, end_date = _dates(demo, now)
        created_at = product_created_at + timedelta(seconds=10)
        auction_status = status_ids[(demo.status, "AUCTION")]
        auction = Auction(
            product_id=product.product_id,
            status_id=auction_status,
            base_price=demo.base_price,
            minimum_increment=demo.increment,
            start_date=start_date,
            end_date=end_date,
            created_at=created_at,
        )
        session.add(auction)
        session.flush()
        created_auctions += 1
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

        if demo.status == "CANCELADA":
            cancelled_at = now
            session.add(AuctionCancellation(
                auction_id=auction.auction_id,
                admin_user_id=admin.user_id,
                reason_detail={"reason": demo.cancellation_reason},
                cancelled_at=cancelled_at,
            ))
            _add_history(session, entity_type="AUCTION", entity_id=auction.auction_id,
                old_status="ACTIVA", new_status="CANCELADA", changed_by=admin.user_id,
                source="ADMIN", changed_at=cancelled_at)

    return created_products, created_auctions


def _expected_auction_history(demo: DemoAuction, auction: Auction, seller_id: int, admin_id: int, cancellation: AuctionCancellation | None):
    expected = {
        (None, "PROGRAMADA", seller_id, "USER", auction.created_at),
    }
    if demo.status != "PROGRAMADA":
        expected.add(("PROGRAMADA", "ACTIVA", None, "SCHEDULER", auction.start_date))
    if demo.status in {"CERRADA", "FINALIZADA_SIN_GANADOR"}:
        expected.add(("ACTIVA", demo.status, None, "SCHEDULER", auction.end_date))
    if demo.status == "CANCELADA" and cancellation is not None:
        expected.add(("ACTIVA", "CANCELADA", admin_id, "ADMIN", cancellation.cancelled_at))
    return expected


def _reset(session: Session, users: dict[str, User]) -> tuple[int, int, int, int, list[str]]:
    seller_id = users["carlos_antiguedades"].user_id
    admin_id = users["admin_subastas"].user_id
    names = [demo.product_name for demo in DEMO_AUCTIONS]
    products = session.scalars(select(Product).where(
        Product.seller_id == seller_id,
        Product.name.in_(names),
        Product.description.like(f"{PRODUCT_MARKER}%"),
    )).all()
    safe_products: list[tuple[Product, DemoAuction, Auction | None]] = []
    messages: list[str] = []
    deleted_products = 0
    deleted_bids = deleted_histories = deleted_cancellations = deleted_auctions = 0

    for product in products:
        demo = next(item for item in DEMO_AUCTIONS if item.product_name == product.name)
        initial_product_history = _product_initial_history(session, product)
        if initial_product_history is None:
            messages.append(f"Se conserva {product.name}: no se pudo confirmar su historial de creación por el seed.")
            continue
        product_histories = session.scalars(select(StatusHistory).where(
            StatusHistory.entity_type == "PRODUCT", StatusHistory.entity_id == product.product_id
        )).all()
        if any(row.history_id != initial_product_history.history_id for row in product_histories):
            messages.append(f"Se conserva {product.name}: tiene cambios de estado ajenos al seed.")
            continue

        auctions = session.scalars(select(Auction).where(Auction.product_id == product.product_id)).all()
        expected_created_at = product.created_at + timedelta(seconds=10)
        demo_auction = next((row for row in auctions if row.created_at == expected_created_at), None)
        unrelated_auctions = [row for row in auctions if row is not demo_auction]
        if demo_auction is None and auctions:
            messages.append(f"Se conserva {product.name}: tiene subastas que no fueron creadas por este seed.")
            continue

        if demo_auction is not None:
            initial_auction_history = _auction_initial_history(session, demo_auction, seller_id)
            if initial_auction_history is None:
                messages.append(f"Se conserva {product.name}: no se pudo confirmar el origen de su subasta.")
                continue
            cancellation = session.get(AuctionCancellation, demo_auction.auction_id)
            if demo.cancellation_reason is not None:
                if (cancellation is None or cancellation.admin_user_id != admin_id
                        or cancellation.reason_detail != {"reason": demo.cancellation_reason}):
                    messages.append(f"Se conserva {product.name}: la cancelación no coincide con la creada por el seed.")
                    continue
            elif cancellation is not None:
                messages.append(f"Se conserva {product.name}: existe una cancelación no creada por el seed.")
                continue

            history_rows = session.scalars(select(StatusHistory).where(
                StatusHistory.entity_type == "AUCTION", StatusHistory.entity_id == demo_auction.auction_id
            )).all()
            expected_history = _expected_auction_history(demo, demo_auction, seller_id, admin_id, cancellation)
            if any((row.old_status_code, row.new_status_code, row.changed_by, row.event_source, row.changed_at) not in expected_history
                   for row in history_rows):
                messages.append(f"Se conserva {product.name}: la subasta tiene cambios de estado ajenos al seed.")
                continue

            postors = [users["mafe_gomez"], users["juanse_mtz"], users["David23"]]
            expected_bids = set(_bid_specs(demo, demo_auction, postors))
            bid_rows = session.scalars(select(Bid).where(Bid.auction_id == demo_auction.auction_id)).all()
            seed_bid_ids = set()
            for bid in bid_rows:
                signature = (bid.participant_id, bid.amount, bid.bid_date)
                if signature in expected_bids:
                    seed_bid_ids.add(bid.bid_id)
            if len(seed_bid_ids) != len([bid for bid in expected_bids]):
                messages.append(f"Se conserva {product.name}: hay pujas que no se pueden atribuir con seguridad al seed.")
                continue

            for bid in bid_rows:
                if bid.bid_id in seed_bid_ids:
                    session.delete(bid)
                    deleted_bids += 1
            if cancellation is not None:
                session.delete(cancellation)
                deleted_cancellations += 1
            for row in history_rows:
                session.delete(row)
                deleted_histories += 1
            session.delete(demo_auction)
            deleted_auctions += 1

        if unrelated_auctions:
            messages.append(f"Se conserva el producto {product.name}: tiene subastas ajenas al seed.")
            safe_products.append((product, demo, None))
        else:
            safe_products.append((product, demo, demo_auction))

    for product, _demo, demo_auction in safe_products:
        if demo_auction is None and session.scalar(select(Auction.auction_id).where(Auction.product_id == product.product_id)) is not None:
            continue
        session.delete(product)
        session.flush()
        initial = _product_initial_history(session, product)
        if initial is not None:
            session.delete(initial)
            deleted_histories += 1
        deleted_products += 1

    return deleted_products, deleted_auctions, deleted_bids, deleted_cancellations, messages


def main() -> int:
    parser = argparse.ArgumentParser(description="Carga o elimina los datos demo de subastas.")
    parser.add_argument("--reset", action="store_true", help="elimina registros identificados como creados por este script")
    args = parser.parse_args()

    if args.reset:
        try:
            answer = input(f'Para confirmar el borrado de datos demo, escribe exactamente "{RESET_PHRASE}": ').strip()
        except (EOFError, KeyboardInterrupt):
            print("Reset cancelado; no se modificó la base de datos.")
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
                result = _reset(session, users)
                session.commit()
                products, auctions, bids, cancellations, messages = result
                print(f"Reset completado: productos={products}, subastas={auctions}, pujas={bids}, cancelaciones={cancellations}.")
                for message in messages:
                    print(message)
            else:
                products, auctions = _seed(session, users)
                session.commit()
                print(f"Seed demo completado: productos nuevos={products}, subastas nuevas={auctions}; los registros existentes se conservaron.")
        return 0
    except Exception as exc:
        print(f"No se pudo completar seed_demo ({type(exc).__name__}).", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
