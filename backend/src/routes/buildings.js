const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/buildingController');

router.get('/', ctrl.listBuildings);
router.post('/', ctrl.createBuilding);
router.get('/:id', ctrl.getBuilding);
router.put('/:id', ctrl.updateBuilding);
router.delete('/:id', ctrl.deleteBuilding);
router.put('/:id/graph', ctrl.updateGraph);

module.exports = router;
