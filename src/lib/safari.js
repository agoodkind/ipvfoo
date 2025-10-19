import { parseIP } from './iputil'

/**
 * Looks up a domain using the native DNS resolver.
 * @param {string} domain - The domain to look up.
 * @returns {Promise<{
 *   addresses: {
 *     address: string;
 *     version: string;
 *   }[];
 *   tcpAddress: string | null;
 * }>} - The result from the native DNS resolver.
 */
export const doNativeLookup = async (domain) => {
  try {
    /**
     * @type {{
     *   error: string | null;
     *   addresses: {
     *     address: string;
     *     version: string;
     *   }[];
     *   tcpAddress: string | null;
     * }}
     */
    const result = await browser.runtime.sendNativeMessage('ipvfoo_helper', {
      cmd: 'lookup',
      domain,
    })

    VERBOSE5: console.log(
      'Native lookup result:',
      'domain=' + domain,
      'tcpAddress=' + result.tcpAddress
    )

    if (result.error) {
      throw new Error(result.error)
    } else {
      return result
    }
  } catch (error) {
    VERBOSE2: console.warn(
      'Native lookup error:',
      'error',
      error,
      'domain',
      domain
    )
    // This seems to be an issue with how the Native App resolves
    // Apparently it blocks localhost lookups
    try {
      // check if the domain is an IP address
      // for ipv6 that means it has [] brackets
      // parseIP does not handle IPs given with []
      let cleanDomain = domain
      if (
        typeof domain === 'string' &&
        domain.startsWith('[') &&
        domain.endsWith(']')
      ) {
        cleanDomain = domain.slice(1, -1)
      }
      // Check if it's a valid IPv4 or IPv6 address using parseIP
      try {
        const packed = parseIP(cleanDomain)
        // parseIP returns 8 hex digits for IPv4, 32 hex digits for IPv6
        const isIPv6 = packed.length === 32
        VERBOSE3: console.log(
          'Got error when looking up domain that is an IP address: ',
          domain,
          'returning as best effort'
        )
        return {
          addresses: [
            {
              address: domain,
              version: isIPv6 ? 'IPv6' : 'IPv4',
            },
          ],
          tcpAddress: domain,
        }
      } catch (e) {
        // Not a valid IP address
        VERBOSE3: console.log(
          'Got error when looking up domain that is an invalid IP address and could not be parsed: ',
          domain
        )
        return null
      }
    } catch {
      VERBOSE3: console.log(
        'Got error when looking up domain that is not an IP address: ',
        domain
      )
      return null
    }
  }
}
// Cache IPv6 connectivity status to avoid repeated checks
let ipv6ConnectivityCache = {
  hasIPv6: null,
  lastCheck: 0,
  checkInterval: 5 * 60 * 1000, // 5 minutes
}

const checkIPv6Connectivity = async () => {
  const now = Date.now()

  // Return cached result if recent
  if (
    ipv6ConnectivityCache.hasIPv6 !== null &&
    now - ipv6ConnectivityCache.lastCheck < ipv6ConnectivityCache.checkInterval
  ) {
    return ipv6ConnectivityCache.hasIPv6
  }

  try {
    // Test IPv6 connectivity by trying to reach Google's IPv6-only test endpoint
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 1000)

    const response = await fetch('https://ipv6.google.com/', {
      method: 'HEAD',
      signal: controller.signal,
    })

    clearTimeout(timeoutId)
    ipv6ConnectivityCache.hasIPv6 = response.ok
  } catch (error) {
    // If the request fails, assume no IPv6 connectivity
    ipv6ConnectivityCache.hasIPv6 = false
  }

  ipv6ConnectivityCache.lastCheck = now
  VERBOSE1: console.log(
    'IPv6 connectivity check:',
    ipv6ConnectivityCache.hasIPv6
  )
  return ipv6ConnectivityCache.hasIPv6
}

// Simple in-memory DNS cache to debounce rapid lookups
const dnsCache = new Map()
const DNS_CACHE_TTL = 10 * 1000 // 10 seconds

// Periodically clean up expired cache entries
setInterval(() => {
  const now = Date.now()
  for (const [key, entry] of dnsCache.entries()) {
    if (now - entry.timestamp >= DNS_CACHE_TTL) {
      dnsCache.delete(key)
      VERBOSE3: console.log('DOH cache entry expired for', key)
    }
  }
}, DNS_CACHE_TTL)

/**
 * Looks up a domain using DNS over HTTPS (DoH) with in-memory caching.
 * @param {string} domain - The domain to look up.
 * @returns {Promise<string>} - The resolved IP address.
 */
export const lookupDomainNative = async (domain) => {
  const now = Date.now()
  // Check cache first
  const cacheEntry = dnsCache.get(domain)
  if (cacheEntry && now - cacheEntry.timestamp < DNS_CACHE_TTL) {
    VERBOSE3: console.log('cache hit for', domain)
    return cacheEntry.ip
  }

  const addresses = await doNativeLookup(domain)

  let address = addresses?.tcpAddress ?? null

  if (address) {
    dnsCache.set(domain, {
      ip: address,
      timestamp: Date.now(),
    })
    VERBOSE3: console.log(
      'result cached for',
      'domain=' + domain,
      'address=' + address
    )
  }

  return address
}
