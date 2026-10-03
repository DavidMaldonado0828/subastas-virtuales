"""Send the same bid concurrently to a running auctions API.

Example: python scripts/concurrency_test.py --url http://localhost:8000 --auction-id 1 --tokens tokenA tokenB --n 12
Alternatively set API_URL, AUCTION_ID, BID_TOKENS (comma separated), N and BID_AMOUNT.
"""
import argparse
import os
from concurrent.futures import ThreadPoolExecutor, as_completed

import httpx


def main() -> None:
    parser = argparse.ArgumentParser(description="Prueba concurrencia de pujas concurrentes con el mismo monto.")
    parser.add_argument("--url", default=os.getenv("API_URL", "http://localhost:8000"))
    parser.add_argument("--auction-id", type=int, default=int(os.getenv("AUCTION_ID", "0")))
    parser.add_argument("--tokens", nargs="+", default=os.getenv("BID_TOKENS", "").split(","))
    parser.add_argument("--n", type=int, default=int(os.getenv("N", "10")))
    parser.add_argument("--amount", default=os.getenv("BID_AMOUNT", "100.00"))
    args = parser.parse_args()
    tokens = [token.strip() for token in args.tokens if token.strip()]
    if not args.auction_id or args.n < 1 or not tokens:
        parser.error("Indique --auction-id, --n positivo y al menos un token (no se imprimen).")
    endpoint = f"{args.url.rstrip('/')}/api/v1/auctions/{args.auction_id}/bids"

    def send(index: int):
        token = tokens[index % len(tokens)]
        try:
            response = httpx.post(endpoint, json={"amount": args.amount}, headers={"Authorization": f"Bearer {token}"}, timeout=30)
            return response.status_code, response.text
        except httpx.HTTPError as error:
            return 0, str(error)

    accepted = rejected = errors = 0
    with ThreadPoolExecutor(max_workers=args.n) as pool:
        futures = [pool.submit(send, i) for i in range(args.n)]
        for future in as_completed(futures):
            code, _ = future.result()
            if code == 201:
                accepted += 1
            elif code:
                rejected += 1
            else:
                errors += 1
    print(f"Aceptadas: {accepted}; rechazadas por API: {rejected}; errores de conexión: {errors}; total: {args.n}")


if __name__ == "__main__":
    main()
