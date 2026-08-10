const state = { year: null, selected: null };
const $ = (selector) => document.querySelector(selector);

async function api(path) {
  const response = await fetch(path, { headers: { Accept: "application/json" } });
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || `Request failed (${response.status})`);
  return response.json();
}

function setStatus(message, kind = "") { const node = $("#status"); node.textContent = message; node.className = `status ${kind}`; }

async function loadYears() {
  const data = await api("/api/v1/years");
  const select = $("#year");
  select.replaceChildren(...data.years.sort((a, b) => b - a).map((year) => { const option = document.createElement("option"); option.value = year; option.textContent = `Tax year ${year}`; return option; }));
  state.year = select.value;
  select.addEventListener("change", () => { state.year = select.value; if (state.selected) loadProperty(state.selected.parcel_id); loadCountyRanking(); });
  setStatus("Choose a result to see the property and its comparable cohort.");
}

function renderResults(data) {
  const container = $("#results"); container.replaceChildren();
  if (!data.results.length) { container.innerHTML = "<p class=\"muted\">No CSV-backed property matched that search.</p>"; return; }
  data.results.forEach((item) => { const button = document.createElement("button"); button.className = "result"; button.innerHTML = `<strong>${item.address || "Address unavailable"}</strong><span>${item.city} · ${item.parcel_id}</span><small>${item.year} effective rate ${item.effective_rate.toFixed(2)}%</small>`; button.addEventListener("click", () => loadProperty(item.parcel_id)); container.append(button); });
}

async function search(event) {
  event.preventDefault();
  const query = encodeURIComponent($("#search-query").value.trim());
  setStatus("Searching CSV-backed records…");
  try { renderResults(await api(`/api/v1/properties/search?q=${query}&year=${state.year}`)); setStatus("Select a property for details."); } catch (error) { setStatus(error.message, "error"); }
}

async function loadProperty(parcelId) {
  try {
    const data = await api(`/api/v1/properties/${encodeURIComponent(parcelId)}?year=${state.year}`);
    state.selected = data.property;
    const property = data.property; const cohort = data.comparables;
    $("#property-title").textContent = property.address || `Parcel ${property.parcel_id}`;
    $("#detail").innerHTML = `<dl class="facts"><dt>Parcel ID</dt><dd>${property.parcel_id}</dd><dt>Tax year</dt><dd>${property.tax_year}</dd><dt>Market value</dt><dd>$${property.market_value.toLocaleString()}</dd><dt>Total tax</dt><dd>$${property.total_tax.toLocaleString()}</dd><dt>Effective rate</dt><dd>${property.effective_rate.toFixed(2)}%</dd><dt>Comparable median</dt><dd>${cohort.median_rate.toFixed(2)}%</dd><dt>Comparable range</dt><dd>${cohort.lower_rate.toFixed(2)}%–${cohort.upper_rate.toFixed(2)}%</dd><dt>Confidence</dt><dd>${cohort.confidence}</dd></dl><p class="method">Eligibility uses levy code, property class, homestead status, and neighborhood before physical similarity. Tax rate is never used to select comparables.</p>`;
    if (window.PropertyMap) window.PropertyMap.show("#property-map", data);
    setStatus(`Showing ${property.parcel_id} for tax year ${property.tax_year}.`);
  } catch (error) { setStatus(error.message, "error"); }
}

async function loadCountyRanking() {
  try { const data = await api(`/api/v1/rankings?year=${state.year}`); $("#ranking-list").innerHTML = data.ranking.map((item, index) => `<div class="ranking-row"><span>${index + 1}</span><strong>${item.rate.toFixed(2)}%</strong><span>${item.address || item.parcel_id}</span><small>${item.parcel_id}</small></div>`).join(""); if (window.CountyMap) window.CountyMap.show("#county-map", data); } catch (error) { setStatus(error.message, "error"); }
}

document.addEventListener("DOMContentLoaded", () => { $("#search-form").addEventListener("submit", search); document.querySelectorAll(".tab").forEach((tab) => tab.addEventListener("click", () => { document.querySelectorAll(".tab").forEach((item) => item.classList.remove("active")); tab.classList.add("active"); document.querySelectorAll(".view").forEach((view) => view.classList.remove("active")); $(`#${tab.dataset.view}-view`).classList.add("active"); if (tab.dataset.view === "county") loadCountyRanking(); })); loadYears().catch((error) => setStatus(error.message, "error")); });
