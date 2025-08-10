import logging
import asyncio
import os
import signal

import aiohttp
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from asusrouter import AsusRouter, AsusData
from asusrouter.modules.port_forwarding import PortForwardingRule

# --- Configuration ---


def read_secret(name):
    with open(name) as f:
        return f.read().strip()


NAS_PRIVATE_IP = os.getenv("NAS_PRIVATE_IP")
ROUTER_HOST = os.getenv("ROUTER_HOST")
ROUTER_USER = os.getenv("ROUTER_USER")
ROUTER_PASS = os.getenv("ROUTER_PASS")
if not ROUTER_PASS:
    secret_file = os.getenv("ROUTER_PW_FILE")
    if secret_file:
        ROUTER_PASS = read_secret(secret_file)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
log = logging.getLogger(__name__)

# --- Core logic to handle the router connection with a reusable session ---


async def with_router_session(session, func):
    """A context manager to manage the AsusRouter object lifecycle
    with a pre-existing aiohttp session."""
    router = AsusRouter(
        hostname=ROUTER_HOST,
        username=ROUTER_USER,
        password=ROUTER_PASS,
        use_ssl=False,
        session=session,
    )
    try:
        await router.async_connect()
        await func(router)
    except Exception:
        log.exception(
            f"An error occurred while running task '{func.__name__}'")
    finally:
        await router.async_disconnect()

# --- Task-specific async functions ---


async def get_aimesh(router: AsusRouter):
    log.info("Starting get_aimesh task...")
    data = await router.async_get_data(AsusData.AIMESH)
    log.info("AiMesh info: %s", data)


async def set_forwarding(router: AsusRouter):
    log.info("Starting set_forwarding task...")
    ruleTcp = PortForwardingRule(
        name="NAS_TCP",
        protocol="TCP",
        port_external=443,
        ip_address=NAS_PRIVATE_IP
    )
    ruleLayer4 = PortForwardingRule(
        name="NAS_Layer4",
        protocol="BOTH",
        port_external=50777,
        ip_address=NAS_PRIVATE_IP
    )
    data = await router.async_apply_port_forwarding_rules([ruleTcp, ruleLayer4])
    log.info("Port forwarding rule set successfully: %s", data)

# --- Scheduler setup ---


async def main():
    """Main async function to start the scheduler and manage the aiohttp session."""
    stop_event = asyncio.Event()

    def shutdown(sig, frame):
        log.info("Shutdown signal received, shutting down gracefully...")
        scheduler.shutdown(wait=True)
        log.info("Scheduler shut down.")
        stop_event.set()

    # Register signal handlers for graceful shutdown
    # SIGINT for local shutdown (Ctrl+C), SIGTERM for Docker
    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    async with aiohttp.ClientSession() as session:
        scheduler = AsyncIOScheduler()

        scheduler.add_job(
            with_router_session,
            'date',
            args=[session, get_aimesh],
            name="Get AiMesh Info on Startup"
        )
        scheduler.add_job(
            with_router_session,
            'interval',
            minutes=15,
            args=[session, set_forwarding],
            name="Set Port Forwarding every 15 minutes"
        )

        log.info("Scheduler started.")
        scheduler.start()

        await stop_event.wait()

if __name__ == "__main__":
    asyncio.run(main())
