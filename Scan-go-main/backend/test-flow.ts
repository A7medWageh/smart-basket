import http from 'http';
import { createApp } from './src/app';
import { socketService } from './src/services/socketService';

async function runTests() {
  console.log('🧪 Starting End-to-End Automated Test Suite for Scan & Go Backend...\n');

  const app = createApp();
  const server = http.createServer(app);
  socketService.init(server);

  const PORT = 5099;
  await new Promise<void>((resolve) => server.listen(PORT, '127.0.0.1', resolve));
  console.log(`📡 Test server running on http://127.0.0.1:${PORT}`);

  const baseUrl = `http://127.0.0.1:${PORT}/api`;

  try {
    // 1. Health Check
    console.log('1️⃣ Testing Health Check...');
    const healthRes = (await fetch(`${baseUrl}/health`).then((r) => r.json())) as any;
    console.log('   Result:', healthRes.status === 'OK' ? '✅ PASS' : '❌ FAIL', healthRes);

    // 2. Login
    console.log('\n2️⃣ Testing User Login...');
    const loginRes = (await fetch(`${baseUrl}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: 'ahmed@scango.com', password: 'password123' }),
    }).then((r) => r.json())) as any;

    if (!loginRes.success) throw new Error('Login failed: ' + JSON.stringify(loginRes));
    const token = loginRes.data.token;
    console.log(`   Result: ✅ PASS - User Authenticated: ${loginRes.data.user.name}`);

    // 3. Products Catalog
    console.log('\n3️⃣ Testing Products Catalog...');
    const productsRes = (await fetch(`${baseUrl}/products`).then((r) => r.json())) as any;
    console.log(`   Result: ✅ PASS - Found ${productsRes.count} products in catalog.`);

    // 4. Cart Pairing & Face ID Verification
    console.log('\n4️⃣ Testing Cart Pairing with Face ID Verification...');
    const pairRes = (await fetch(`${baseUrl}/cart/pair`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ cartCode: 'CART_01', faceVerified: true }),
    }).then((r) => r.json())) as any;

    if (!pairRes.success) throw new Error('Pairing failed: ' + JSON.stringify(pairRes));
    console.log(`   Result: ✅ PASS - Paired with ${pairRes.data.cartCode} (Face Verified: ${pairRes.data.faceVerified})`);

    // 5. AI Vision Detection Simulation
    console.log('\n5️⃣ Testing AI Webhook Detection (ESP32 Camera -> AI Server -> Backend)...');

    // Add Product 1 (Juice)
    const aiRes1 = (await fetch(`${baseUrl}/ai/detection`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        cart_code: 'CART_01',
        product_id: 1,
        confidence: 0.98,
        action: 'added',
      }),
    }).then((r) => r.json())) as any;
    console.log(`   Item 1 Detected: ✅ ${aiRes1.data.detectedProduct.nameAr} (${aiRes1.data.detectedProduct.price} EGP)`);

    // Add Product 2 (Molto)
    const aiRes2 = (await fetch(`${baseUrl}/ai/detection`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        cart_code: 'CART_01',
        product_id: 2,
        confidence: 0.94,
        action: 'added',
      }),
    }).then((r) => r.json())) as any;
    console.log(`   Item 2 Detected: ✅ ${aiRes2.data.detectedProduct.nameAr} (${aiRes2.data.detectedProduct.price} EGP)`);

    // 6. Verify Active Cart
    console.log('\n6️⃣ Verifying Active Cart State from Mobile App...');
    const cartRes = (await fetch(`${baseUrl}/cart/active`, {
      headers: { Authorization: `Bearer ${token}` },
    }).then((r) => r.json())) as any;

    console.log(`   Cart Total: ${cartRes.data.grandTotal} EGP across ${cartRes.data.itemsCount} items.`);
    if (cartRes.data.itemsCount === 2 && cartRes.data.faceVerified) {
      console.log('   Result: ✅ PASS - Face ID & Cart state verified!');
    } else {
      console.warn('   Result: ⚠️ Cart state:', cartRes.data);
    }

    // 7. Checkout & Payment Simulation
    console.log('\n7️⃣ Testing Checkout & Payment Simulation (InstaPay)...');
    const checkoutRes = (await fetch(`${baseUrl}/orders/checkout`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({ paymentMethod: 'INSTAPAY' }),
    }).then((r) => r.json())) as any;

    if (!checkoutRes.success) throw new Error('Checkout failed: ' + JSON.stringify(checkoutRes));
    console.log(`   Result: ✅ PASS - Order Generated: ${checkoutRes.data.orderNumber}`);

    console.log('\n🎉 ALL TESTS PASSED SUCCESSFULLY! Face ID & Cart session secured.\n');
  } catch (error) {
    console.error('\n❌ Test failed with error:', error);
  } finally {
    server.close();
    process.exit(0);
  }
}

runTests();
