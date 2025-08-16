from datetime import datetime
import logging
import asyncio
import os
import signal
import sys

import aiohttp
from apscheduler import AsyncScheduler
from apscheduler.triggers.date import DateTrigger
from apscheduler.triggers.interval import IntervalTrigger

from asusrouter import AsusRouter, AsusData
from asusrouter.modules.port_forwarding import PortForwardingRule, AsusPortForwarding

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
    enableforwardingdata = await router.async_set_state(AsusPortForwarding.ON)
    log.info("Port forwarding set to enabled successfully: %s",
             enableforwardingdata)

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
    forwardingdata = await router.async_apply_port_forwarding_rules([ruleTcp, ruleLayer4])
    log.info("Port forwarding rules set successfully: %s", forwardingdata)

# --- Scheduler setup ---


async def main():
    session = aiohttp.ClientSession()
    scheduler = AsyncScheduler()
    loop = asyncio.get_running_loop()

    # Single shutdown handler that works on all platforms
    def shutdown(*args):
        log.info("Shutdown initiated.")
        asyncio.create_task(scheduler.stop())

    if sys.platform == "win32":  # https://github.com/python/cpython/issues/137863
        for sig in (signal.SIGINT, signal.SIGTERM):
            signal.signal(sig, shutdown)
    else:
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, shutdown)

    async with scheduler:
        await scheduler.add_schedule(
            with_router_session,
            trigger=DateTrigger(run_time=datetime.now()),
            args=[session, get_aimesh],
            id="Get AiMesh Info on Startup"
        )
        await scheduler.add_schedule(
            with_router_session,
            trigger=IntervalTrigger(minutes=15),
            args=[session, set_forwarding],
            id="Set Port Forwarding every 15 minutes"
        )
        await scheduler.run_until_stopped()
        await session.close()
        log.info("HTTP session closed.")

    log.info("Script finished.")

if __name__ == "__main__":
    asyncio.run(main())
