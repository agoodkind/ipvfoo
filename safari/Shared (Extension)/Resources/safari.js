const doNativeLookup = async (domain) => {
  try {
    const result = await browser.runtime.sendNativeMessage("ipvfoo_helper", {
      cmd: "lookup",
      domain,
    });

    if (result.error) {
      throw new Error(result.error);
    } else {
      return result.addresses;
    }
  } catch (error) {
    debugLog("Native lookup error:", error);
    return null;
  }
};

// Cache IPv6 connectivity status to avoid repeated checks
let ipv6ConnectivityCache = {
  hasIPv6: null,
  lastCheck: 0,
  checkInterval: 5 * 60 * 1000, // 5 minutes
};

const checkIPv6Connectivity = async () => {
  const now = Date.now();

  // Return cached result if recent
  if (
    ipv6ConnectivityCache.hasIPv6 !== null &&
    now - ipv6ConnectivityCache.lastCheck < ipv6ConnectivityCache.checkInterval
  ) {
    return ipv6ConnectivityCache.hasIPv6;
  }

  try {
    // Test IPv6 connectivity by trying to reach Google's IPv6-only test endpoint
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 1000);

    const response = await fetch("https://ipv6.google.com/", {
      method: "HEAD",
      signal: controller.signal,
    });

    clearTimeout(timeoutId);
    ipv6ConnectivityCache.hasIPv6 = response.ok;
  } catch (error) {
    // If the request fails, assume no IPv6 connectivity
    ipv6ConnectivityCache.hasIPv6 = false;
  }

  ipv6ConnectivityCache.lastCheck = now;
  debugLog("IPv6 connectivity check:", ipv6ConnectivityCache.hasIPv6);
  return ipv6ConnectivityCache.hasIPv6;
};

// Simple in-memory DNS cache for Safari web extensions
const dnsCache = new Map();
const DNS_CACHE_TTL = 10 * 1000; // 10 seconds
const DNS_CACHE_MAX_SIZE = 100;

// Periodically clean up expired cache entries
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of dnsCache.entries()) {
    if (now - entry.timestamp >= DNS_CACHE_TTL) {
      dnsCache.delete(key);
      debugLog("DOH cache entry expired for", key);
    }
  }
}, DNS_CACHE_TTL);

/**
 * Looks up a domain using DNS over HTTPS (DoH) with in-memory caching.
 * @param {string} domain - The domain to look up.
 * @returns {Promise<string>} - The resolved IP address.
 */
const lookupDomainNative = async (domain) => {
  // Check cache first
  const cacheEntry = dnsCache.get(domain);
  if (cacheEntry && now - cacheEntry.timestamp < DNS_CACHE_TTL) {
    debugLog("cache hit for", domain);
    return cacheEntry.ip;
  }

  const [addresses, hasV6Connectivity] = await Promise.all([
    doNativeLookup(domain),
    checkIPv6Connectivity(),
  ]);
  let address;
  if (addresses.length > 0) {
    const ipv4 = addresses.find((a) => a.version === "v4");
    const ipv6 = addresses.find((a) => a.version === "v6");
    if (hasV6Connectivity && ipv6) {
      address = ipv6.address;
    } else if (ipv4) {
      address = ipv4.address;
    } else {
      address = null;
    }

    if (address) {
      dnsCache.set(domain, {
        ip: address,
        timestamp: Date.now(),
      });
      debugLog("result cached for", domain);
      return address;
    }
  }
  return null;
};
