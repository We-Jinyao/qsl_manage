/**
 * Welcome to Cloudflare Workers! This is your first worker.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Bind resources to your worker in `wrangler.jsonc`. After adding bindings, a type definition for the
 * `Env` object can be regenerated with `npm run cf-typegen`.
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */
import { FetchEvent, ScheduledEvent } from '@cloudflare/workers-types';
import { AuthMiddleware, AuthRoutes, AuthEnv } from './auth';

export interface Env {
	DB: D1Database;
	API_SECRET: string;
	JWT_PUBLIC_KEY: string;
	USER_KV: KVNamespace;
	RATE_LIMIT_KV: KVNamespace;
}


interface QSL_info{
	to_callsign: string;
	received: boolean;
	sent: boolean;
	received_date: Date|null;
	sent_date: Date|null;
}

interface update_info{
	qsl_card_id: string;
	received?: boolean;
	sent?: boolean;
	received_date?: Date|null;
	sent_date?: Date|null;
}


type ResultList<T> = T[];


function getHeaders(request: Request): Headers {
	// 允许的源（生产环境建议指定具体域名，而非*）
	const allowedOrigin = "*"; // 开发环境可用*，生产环境需限制

	// 允许的HTTP方法
	const allowedMethods = "GET, POST, OPTIONS";

	// 允许的请求头
	const allowedHeaders = "Content-Type, Authorization, X-Requested-With";

	// 预检请求的有效期（秒），在此期间无需重复发送预检请求
	const maxAge = "86400"; // 24小时

	// 设置CORS响应头
	const headers = new Headers();
	headers.append("Access-Control-Allow-Origin", allowedOrigin);
	headers.append("Access-Control-Allow-Methods", allowedMethods);
	headers.append("Access-Control-Allow-Headers", allowedHeaders);
	headers.append("Access-Control-Max-Age", maxAge);

	headers.append("Access-Control-Allow-Credentials", "true");
	return headers;
	// 返回204 No Content响应（标准做法）
}


async function handleFetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
	const url = new URL(request.url);
	const qsl_trans = new QSL_Transaction();
	const headers = getHeaders(request);
	if (request.method === "OPTIONS") {
		return new Response(null, {
			status: 204,
			headers: headers
		});
	}
	if (request.method === "GET") {
		if (url.pathname === "/") {
			const callsign = url.searchParams.get("callsign");
			if (callsign) {
				return await qsl_trans.query_qsl(callsign, env);
			}
			return new Response("Param callsign needed!", {status: 401,headers: headers});
		} else {
			return new Response("Unknown pathname " + url.pathname, { status: 404,headers: headers });
		}
	}

	if (request.method === "POST") {
		const auth_routes = new AuthRoutes();
		const AUTH_ENV: AuthEnv = {
			API_SECRET: env.API_SECRET,
			JWT_PUBLIC_KEY: env.JWT_PUBLIC_KEY,
			USER_KV: env.USER_KV,
			RATE_LIMIT_KV: env.RATE_LIMIT_KV,
		} as AuthEnv;
		switch (url.pathname) {
			case "/":
				return new Response("Unknown endpoint!", {status: 200});
			case "/login":
				return await auth_routes.login(request, AUTH_ENV);
		}

		if (!tryAuth(request, AUTH_ENV)) {
			return new Response("Permission denied! 鉴权失败，请登录后再试！", { status: 401 });
		}
		try {
			switch (url.pathname) {
				case "/add_new_qsl":
					const qsl_info = await request.json() as QSL_info;
					return await qsl_trans.add_new_qsl(qsl_info, env);
				case "/delete_qsl":
					const req_json: any = await request.json();
					const target_qsl = req_json.qsl_card_id as number;
					return await qsl_trans.delete_qsl(target_qsl, env);
				case "/update_qsl":
					const update_info = await request.json() as update_info;
					return await qsl_trans.update_qsl(update_info, env);
				case "/isAuthenticated":
					return new Response("Auth success!", {status: 200})
			}
			return new Response("Unknown endpoint!", {status: 404});
		} catch (error) {
			return new Response("Parse request failed! 解析错误！"+error, {status: 500});
		}
	}
	return new Response("Method not allowed", { status: 405 });
};

async function tryAuth(req: Request, env: AuthEnv
): Promise<boolean> {
	const auth_middleware = new AuthMiddleware();
	const auth_result = await auth_middleware.authenticate(req, env);
	return auth_result.isAuthenticated;
}

// 定时任务清理超期记录
async function handleScheduled(event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
	const retentionPeriod = 90; // 数据保留期限（天）
	const db = env.DB;
	var clsNum = 0;
	var successNumb = 0;
	try{
		const session = db.withSession();
		const result = await session.prepare(
			'SELECT QSLCardId FROM QSLInfo WHERE CreatedDate < ?'
		).bind(new Date(Date.now() -retentionPeriod * 24 * 60 * 60 * 1000)).run();
		let prepareArray = [];
		for (const row of result.results) {
			prepareArray.push(			session.prepare(
				'DELETE FROM QSLInfo WHERE QSLCardId = ?'
			).bind(row.QSLCardId));
			clsNum++;
		}
		const results = await session.batch(prepareArray);
		for (const row of results) {
			if (row.success) {
				successNumb++;
			}
		}
	}catch (error) {
		console.error(error);
		console.log(`Data cleanup failed! Total ${clsNum} rows detected, but ${successNumb} rows deleted succesfully.`);
		throw error;
	  }
	console.log('Data cleanup completed.\n' + `${clsNum} rows detected, and ${successNumb} rows detected.!`);
};

export function jsonResponse(
	data: any,
	status: number = 200
): Response {
	return new Response(
		JSON.stringify(data),  // 关键：将对象序列化为JSON字符串
		{
			status,
			headers: {
				'Content-Type': 'application/json;charset=UTF-8',  // 正确设置JSON类型头
				'Access-Control-Allow-Origin': '*',  // 跨域需要时添加
			}
		}
	);
}

class QSL_Transaction{
	async update_qsl(update_info: update_info, env: Env): Promise<Response> {
		const qsl_db = env.DB;
		const { qsl_card_id, ...updateFields } = update_info;

		if (Object.keys(updateFields).length === 0) {
			return new Response("No fields to update", { status: 400 });
		}

		// 构建更新的SQL语句和参数
		const updateColumns: string[] = [];
		const params: (boolean | Date | null | string)[] = [];

		// 处理每个更新字段
		if (updateFields.received !== undefined) {
			updateColumns.push("Received = ?");
			params.push(updateFields.received);
		}

		if (updateFields.sent !== undefined) {
			updateColumns.push("Sent = ?");
			params.push(updateFields.sent);
		}

		if (updateFields.received_date !== undefined) {
			updateColumns.push("ReceivedDate = ?");
			params.push(updateFields.received_date);
		}

		if (updateFields.sent_date !== undefined) {
			updateColumns.push("SentDate = ?");
			params.push(updateFields.sent_date);
		}

		// 添加主键
		params.push(qsl_card_id);

		const sql = `UPDATE QSLInfo SET ${updateColumns.join(", ")} WHERE QSLCardId = ?`;

		try {
			// 执行更新操作
			const result = await qsl_db.prepare(sql).bind(...params).run();

			if (result.meta.changes > 0) {
				return new Response("QSL updated successfully", { status: 200 });
			} else {
				return new Response("No QSL record found with the provided ID", { status: 404 });
			}
		} catch (error) {
			console.error("Error updating QSL:", error);
			return new Response("Failed to update QSL", { status: 500 });
		}
	}

	async add_new_qsl(qsl_info: QSL_info, env: Env): Promise<Response> {
		const qsl_db = env.DB;
		const callsign = qsl_info.to_callsign.toUpperCase();
		const received = qsl_info.received;
		const sent = qsl_info.sent;
		const received_date = qsl_info.received_date;
		const sent_date = qsl_info.sent_date;
		const updateColumns: string[] = [];
		const params: (boolean | Date | string)[] = [];
		updateColumns.push("ToCallsign");
		params.push(callsign);
		if (received !== undefined) {
			updateColumns.push("Received");
			params.push(received);
		}

		if (sent !== undefined) {
			updateColumns.push("Sent");
			params.push(sent);
		}

		if (received_date !== undefined && received_date !== null) {
			updateColumns.push("ReceivedDate");
			params.push(received_date);
		}

		if (sent_date !== undefined && sent_date !== null) {
			updateColumns.push("SentDate");
			params.push(sent_date);
		}
		const valBindSymbol = new Array(params.length).fill('?').join(", ").toString();

		const SQL = `INSERT INTO QSLInfo (${updateColumns.join(", ")}) VALUES (${valBindSymbol})`;
		console.log(SQL);
		const qsl = await qsl_db.prepare(SQL).bind(...params).run();
		if (qsl.meta.rows_written > 0) {
			return new Response("QSL added", { status: 200 });
		} else {
			return new Response("Failed to add QSL", { status: 500 });
		}
	}

	async query_qsl(callsign: string, env: Env): Promise<Response> {
		const qsl_db = env.DB;
		const qsl_list = await qsl_db.prepare("SELECT * FROM QSLInfo WHERE ToCallsign = ?").bind(callsign.toUpperCase()).all();
		return await jsonResponse(qsl_list,200);
	}

	async delete_qsl(qsl_card_id: number, env: Env): Promise<Response> {
		const qsl_db = env.DB;
		const delete_result = await qsl_db.prepare(
			'DELETE FROM QSLInfo WHERE QSLCardId = ?'
		).bind(qsl_card_id).run();
		if (delete_result) {
			return new Response("QSL deleted successfully", { status: 200 });
		}else {
			return new Response("Failed to delete", { status: 404 });
		}
	}
}





export default {

	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		return handleFetch(request, env, ctx);
	  },

	async scheduled(event: ScheduledController, env: Env, ctx: ExecutionContext): Promise<void> {
		await handleScheduled(event, env, ctx);
	  },

};
