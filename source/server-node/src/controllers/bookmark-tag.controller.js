const service = require("../services/bookmark-tag.service");

async function list(req, res, next) { try { res.json({ tags: await service.list(req.auth.sub, req.query) }); } catch (error) { next(error); } }
async function create(req, res, next) { try { res.status(201).json({ tag: await service.create(req.auth.sub, req.body) }); } catch (error) { next(error); } }
async function update(req, res, next) { try { res.json({ tag: await service.update(req.auth.sub, req.params.id, req.body) }); } catch (error) { next(error); } }
async function remove(req, res, next) { try { await service.remove(req.auth.sub, req.params.id, req.query); res.status(204).send(); } catch (error) { next(error); } }

module.exports = { list, create, update, remove };
