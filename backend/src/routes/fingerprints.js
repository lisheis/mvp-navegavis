const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/fingerprintController');

router.get('/', ctrl.listFingerprints);
router.post('/', ctrl.createFingerprint);
// Specific route for clearing building fingerprints must come before the generic '/:id'
router.delete('/building/:buildingId', ctrl.clearBuildingFingerprints);
router.delete('/:id', ctrl.deleteFingerprint);
router.post('/estimate', ctrl.estimatePosition);

module.exports = router;
