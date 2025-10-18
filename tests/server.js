#!/usr/bin/env node
const http = require('http')
const fs = require('fs')
const path = require('path')

http.createServer((req, res) => {
  console.log(`${req.method} ${req.url}`)
  
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  
  if (req.method === 'OPTIONS') {
    res.writeHead(204)
    res.end()
    return
  }
  
  if (req.url === '/ping') {
    res.writeHead(200, {'Content-Type': 'text/plain'})
    res.end('pong')
    return
  }
  
  if (req.url === '/' || req.url === '/test.html') {
    fs.readFile(path.join(__dirname, 'test.html'), (err, data) => {
      if (err) {
        res.writeHead(404)
        res.end('Not found')
        return
      }
      res.writeHead(200, {'Content-Type': 'text/html'})
      res.end(data)
    })
    return
  }
  if (req.url === '/favicon.ico') {
    res.writeHead(200, {'Content-Type': 'image/x-icon'})
    // Generate random favicon data (16x16 black/white PNG)
    const icon = Buffer.from(
      "89504e470d0a1a0a0000000d49484452000000100000001008060000001f" +
      "f3ffa000000006624b474400ff00ffa0bda793000000097048597300000b13" +
      "00000b1301009a9c180000000774494d4507e7091a10142263d87a06000000" +
      "1974455874536f667477617265007061696e742e6e657420342e302e31f8ea" +
      "fd26000001b54944415438519d933d48335114c7cfbf3b9dcc50068e4be9bd" +
      "1ca7a02bd18bc73c3b2cdd99b7b75c42c623c2094e4e470ed976e7f6e6d170" +
      "c8c29541c6c1bf1f81fba56ede5ae5e77c2d2b9d9056032a443ad4b7d6b6d5" +
      "f413a99542b6839358931c185234b63afd8c3c1e0fb8d50c2b16a6b1642c58" +
      "bbb9caa8ea7fd096dbb7ee749400b81236e757cd0e1a563b77bd0f464d6f2f" +
      "fd4bd4bf92251e91fc9e724c53bc14dffe62ad63e663f750cb93727ed2d1e9" +
      "f8e8dc2eab4440aeec9afd12bad2d6b04488f806f31b3c3cfb729a4b1860e8" +
      "7a42107e6faef3d151b494f5e5a0e9569f25511fe4ea00ef507353822cf5b1" +
      "e032f2c5ca12f072bf4b086232e537222dbf2c4c4fbb9eeb37ad894b4120c2" +
      "242f158c8cf7247c37e498a5a2044c936270582db0f8e22e001667f082eb12" +
      "812fe323ba4fa614c620ee13d97aafb4f68adcec60c2dcfc4d55c66a12e3ec" +
      "4a7f573c59c9934e0c69f47630d5597620c7cb3e7bae615a7fe5048666b544" +
      "da151b64c32d9da20000000049454e44ae426082", "hex"
    );
    res.end(icon);
    return
  }
  
  res.writeHead(404)
  res.end('Not found')
}).listen(8080, () => {
  console.log('Server running at http://localhost:8080')
  console.log('Visit http://localhost:8080/ to run tests')
})

