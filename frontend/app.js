// Paste the three hashes and the measured full-loop value after scripts/trigger-move.sh.
// No keys or secrets belong in this file.
const DEPLOYED = {
  chainId: 84532,
  thresholdBps: 50,
  reactive: "0x82d75EFbCA8e086565cB2CCEb270B0625dE6b348",
  executor: "0xd666DCE5C51c36D24c513AE98767229FC3fbAa40",
  pool: "0x77B728A427a331485e0B20D4cfE0ce7346D9DA83",
  originTx: "0xee337905c0af4ab06e51df3dcf5d9c70cc3ac57956f83b542da6219e24b36389",
  reactiveTx: "0x4eb6803b85a84d1f01b033e8438ab8bb733c2fc6f290cf9d9be7b4a50a05398d",
  callbackTx: "0x09f1b1c36954c1185d162283d999db7a3e613c5534b6c57c25c3d10e37e1bf9a",
  fullLoopMs: 2000,
  measuredAt: "2026-11-08T10:35:28Z"
};

const ADDRESS_RE = /^0x[a-fA-F0-9]{40}$/;
const TX_RE = /^0x[a-fA-F0-9]{64}$/;

const explorerBase = (chainId) => {
  if (chainId === 1301) return "https://sepolia.uniscan.xyz";
  return "https://sepolia.basescan.org";
};

const short = (value) => `${value.slice(0, 6)}…${value.slice(-4)}`;

const externalLink = (href, label, accessibleName) => {
  const link = document.createElement("a");
  link.href = href;
  link.textContent = label;
  link.target = "_blank";
  link.rel = "noopener noreferrer";
  if (accessibleName) link.setAttribute("aria-label", accessibleName);
  return link;
};

const renderContracts = () => {
  const rows = [
    {
      key: "reactive",
      chain: "Lasna 5318007",
      href: (value) => `https://reactscan.net/address/${value}`,
      label: "View on Reactscan"
    },
    {
      key: "executor",
      chain: `Chain ${DEPLOYED.chainId}`,
      href: (value) => `${explorerBase(DEPLOYED.chainId)}/address/${value}`,
      label: "View on explorer"
    },
    {
      key: "pool",
      chain: "Uniswap V2 pair",
      href: (value) => `${explorerBase(DEPLOYED.chainId)}/address/${value}`,
      label: "View on explorer"
    }
  ];

  for (const row of rows) {
    const element = document.querySelector(`[data-contract="${row.key}"]`);
    if (!element) continue;

    const address = DEPLOYED[row.key];
    const addressElement = element.querySelector(".contract-address");
    const linkElement = element.querySelector(".contract-link");
    if (!ADDRESS_RE.test(address || "")) continue;

    addressElement.textContent = address;
    linkElement.replaceChildren(
      externalLink(row.href(address), row.label, `${row.key} contract ${address}`)
    );
  }
};

const renderLatency = () => {
  const status = document.getElementById("run-status");
  const body = document.getElementById("latency-body");
  if (!status || !body) return;

  const hashes = [DEPLOYED.originTx, DEPLOYED.reactiveTx, DEPLOYED.callbackTx];
  const complete = hashes.every((value) => TX_RE.test(value || ""));
  const hasLatency = Number.isFinite(DEPLOYED.fullLoopMs);

  if (!complete || !hasLatency) {
    status.textContent = complete ? "Run recorded, latency pending" : "Awaiting first funded run";
    return;
  }

  const cells = [
    {
      label: "Origin tx",
      value: DEPLOYED.originTx,
      href: `${explorerBase(DEPLOYED.chainId)}/tx/${DEPLOYED.originTx}`,
      linkLabel: "View origin"
    },
    {
      label: "Reactive tx",
      value: DEPLOYED.reactiveTx,
      href: `https://reactscan.net/tx/${DEPLOYED.reactiveTx}`,
      linkLabel: "View reactive"
    },
    {
      label: "Callback tx",
      value: DEPLOYED.callbackTx,
      href: `${explorerBase(DEPLOYED.chainId)}/tx/${DEPLOYED.callbackTx}`,
      linkLabel: "View callback"
    }
  ];

  const row = document.createElement("tr");

  for (const cell of cells) {
    const td = document.createElement("td");
    td.dataset.label = cell.label;
    const link = externalLink(cell.href, short(cell.value), `${cell.linkLabel} ${cell.value}`);
    link.title = cell.value;
    td.append(link);
    row.append(td);
  }

  const latencyCell = document.createElement("td");
  latencyCell.dataset.label = "Full-loop ms";
  latencyCell.textContent = `${new Intl.NumberFormat("en-US").format(Math.round(DEPLOYED.fullLoopMs))} ms`;
  row.append(latencyCell);

  body.replaceChildren(row);
  status.textContent = DEPLOYED.measuredAt ? `Measured ${DEPLOYED.measuredAt}` : "Measured";
};

const renderThreshold = () => {
  if (!Number.isFinite(DEPLOYED.thresholdBps)) return;
  const label = document.getElementById("threshold-label");
  const note = document.getElementById("threshold-note");
  if (label) label.textContent = `${DEPLOYED.thresholdBps} bps`;
  if (note) note.textContent = `${DEPLOYED.thresholdBps} bps demo`;
};

document.addEventListener("DOMContentLoaded", () => {
  try {
    renderContracts();
    renderLatency();
    renderThreshold();
  } catch (error) {
    const status = document.getElementById("run-status");
    if (status) status.textContent = "Run data unavailable";
    console.error("OmniStop render failed", error);
  }

  const year = document.getElementById("year");
  if (year) year.textContent = String(new Date().getFullYear());
});
