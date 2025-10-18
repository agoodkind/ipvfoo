
const doNativeLookup = async (domain) => {
  try {
    const result = await browser.runtime.sendNativeMessage("ipvfoo_helper", {
      cmd: "lookup",
      domain
    });

    if (result.error) {
      throw new Error(result.error);
    } else {
      return result.ip;
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
  checkInterval: 5 * 60 * 1000 // 5 minutes
};

const checkIPv6Connectivity = async () => {
  const now = Date.now();
  
  // Return cached result if recent
  if (ipv6ConnectivityCache.hasIPv6 !== null && 
      now - ipv6ConnectivityCache.lastCheck < ipv6ConnectivityCache.checkInterval) {
    return ipv6ConnectivityCache.hasIPv6;
  }

  try {
    // Test IPv6 connectivity by trying to reach Google's IPv6-only test endpoint
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 1000);
    
    const response = await fetch('https://ipv6.google.com/', {
      method: 'HEAD',
      signal: controller.signal
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

const cloudflareDOHUrl = (domain, type) => `https://cloudflare-dns.com/dns-query?name=${domain}&type=${type}`;
const googleDOHUrl = (domain, type) => `https://dns.google/resolve?name=${domain}&type=${type}`;

/**
 * @param {string} domain 
 * @param {string} type 
 * @returns {Promise<{
 *   Answer: {TTL: number, data: string, name: string, type: number}[]
 * }|null>}
 */
const doSingleDOHLookup = async (domain, type) => {
  let randomValue = Math.floor(Math.random() * 2); // 0 or 1
  let url;
  if (randomValue) {
    url = cloudflareDOHUrl(domain, type);
  } else {
    url = googleDOHUrl(domain, type);
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 200);

    const response = await fetch(url, {
      headers: { 'Accept': 'application/dns-json' },
      signal: controller.signal
    });
      
    clearTimeout(timeoutId);

    return await response.json();
  } catch (error) {
    debugLog("DOH lookup failed:", error);
  }

  return null;
}

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
const lookupDomainDOH = async (domain) => {

  await doNativeLookup(domain);
  const now = Date.now();
  
  // Check cache first
  const cacheEntry = dnsCache.get(domain);
  if (cacheEntry && (now - cacheEntry.timestamp < DNS_CACHE_TTL)) {
    debugLog("DOH cache hit for", domain);
    return cacheEntry.ip;
  }

  const hasV6Connectivity = await checkIPv6Connectivity();

  const promises = []
  if (hasV6Connectivity) {
    promises.push(
      doSingleDOHLookup(domain, 'AAAA')
    );
  }

  // This will also use HTTP/2 multiplexing to request both A and AAAA records in parallel
  promises.push(doSingleDOHLookup(domain, 'A'));
  
  try {
    const jsonResults = await Promise.all(promises)
    /**
     * @type {{
     *   TTL: number,
     *   data: string,
     *   name: string,
     *   type: number,
     * }[]}
     */
    const allResults = jsonResults.flatMap(result => result.Answer || []);
    const ip = allResults
      .filter(d => d.type === 28 || d.type === 1)
      // only include AAAA (28) and A (1) records
      .map(d => d.data)[0] || null;

    // Cache the result
    if (ip) {
      dnsCache.set(domain, {
        ip: ip,
        timestamp: now
      });
      debugLog("DOH result cached for", domain);
    }

    return ip;
  } catch (error) {
    debugLog("DOH lookup failed:", error);
    return null;
  }
};