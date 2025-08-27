/**
 * 鉴权中间件和路由处理
 * 判断请求是否包含JWT令牌
 * 		若包含令牌，验证JWT令牌并返回鉴权结果
 * 		若不包含令牌，则执行登录逻辑
 */
import * as jose from 'jose';
import * as bcrypt from 'bcryptjs';

// 以分钟计JWT令牌默认有效期
const JWT_EXP_TIME: number = 72*24*60;
const RATE_LIMIT = {
	user: -1,
	ip: 10,
}

export class AuthMiddleware {
	// 验证API密钥
	private verifyApiKey(apiKey: string | null, env: AuthEnv): boolean {
		if (!apiKey) return false;
		return apiKey === env.API_SECRET;
	}

	// 验证JWT令牌
	private async verifyJwt(token: string | null, env: AuthEnv): Promise<boolean | { userId: string }> {
		if (!token) return false;

		try {
			const publicKey = env.JWT_PUBLIC_KEY;
			if (!publicKey) throw new Error('请设置鉴权使用的公钥！ Public key not found!');

			const { payload } = await jose.jwtVerify(
				token,
				new TextEncoder().encode(publicKey),
				{ algorithms: ['HS256'] }
			);

			if (payload.exp && payload.exp < Date.now() / 1000) {
				return false;
			}

			return { userId: payload.sub as string };
		} catch (error) {
			console.error('JWT鉴权失败 JWT verification failed:', error);
			return false;
		}
	}

	// 鉴权主方法
	async authenticate(request: Request, env: AuthEnv): Promise<{
		isAuthenticated: boolean;
		user?: { userId: string };
		error?: string
	}> {
		// 1. 检查API密钥鉴权
		const apiKey = request.headers.get('X-API-Key');
		if (apiKey && this.verifyApiKey(apiKey, env)) {
			return { isAuthenticated: true, user: { userId: 'service' } };
		}

		// 2. 检查Bearer令牌鉴权
		const authHeader = request.headers.get('Authorization');
		const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
		if (token) {
			const jwtResult = await this.verifyJwt(token, env);
			if (jwtResult !== false) {
				return { isAuthenticated: true, user: jwtResult as { userId: string } };
			}
		}

		// 鉴权失败
		return {
			isAuthenticated: false,
			error: 'Unauthorized - Invalid or missing authentication'
		};
	}

}

export class AuthRoutes {
	// 登录处理
	async login(request: Request, env: AuthEnv): Promise<Response> {
		try {
			interface LoginData {
				username: string;
				password: string;
			}
			const { username, password } = await request.json() as LoginData;
			console.log("Traying to login");
			// 验证用户凭据
			const user = await this.validateUserCredentials(username, password, env);
			if (!user) {
				return new Response(JSON.stringify({ error: 'Invalid credentials' }), {
					status: 401,
					headers: { 'Content-Type': 'application/json' }
				});
			}
			if (RATE_LIMIT.user>0) {
				//用户限流处理
				const getDayNumber = () => {
					const timestamp = Date.now(); // 毫秒级时间戳
					const secondsPerDay = 24 * 60 * 60; // 86400秒/天
					return Math.floor(timestamp / 1000 / secondsPerDay);
				};
				const user_rate_limit: string =  getDayNumber().toString();
				const rate_now = await env.RATE_LIMIT_KV.get(user.id+":"+user_rate_limit);
				if(!rate_now){
					await env.RATE_LIMIT_KV.put(user.id+":"+user_rate_limit,"1",{expiration: (getDayNumber()+1) *24*60*60});
				}else if(parseInt(rate_now)<RATE_LIMIT.user){
					await env.RATE_LIMIT_KV.put(user.id+":"+user_rate_limit,(parseInt(rate_now)+1).toString());
				}else{
					throw Error("Too many user login times! Try in 24 hours!");
				}
			}


			// 生成JWT令牌
			const jwtToken = await this.generateJwt(user.id, env);

			// 构建响应
			const response = new Response(JSON.stringify({
				message: 'Login successful',
				token: jwtToken,
				user: { id: user.id }
			}), {
				headers: { 'Content-Type': 'application/json' }
			});
			return response;
		} catch (error) {
			console.error('Login error:', error);
			return new Response(JSON.stringify({ error: 'Login failed:'+error }), {
				status: 500,
				headers: { 'Content-Type': 'application/json' }
			});
		}
	}

	// 验证用户凭据
	private async validateUserCredentials(username: string, password: string, env: AuthEnv): Promise<{ id: string} | null> {
		// 实际应用中查询数据库并验证密码哈希
		const user_passhash = await env.USER_KV.get(username);

		if (!user_passhash) return null;

		// 验证密码
		const isValid = await this.verifyPassword(password, user_passhash);
		return isValid ? { id: username } : null;
	}

	// 生成JWT
	private async generateJwt(userId: string, env: AuthEnv): Promise<string> {
		const secret = env.JWT_PUBLIC_KEY;
		if (!secret) throw new Error('JWT secret not found');

		const exp = Math.floor(Date.now() / 1000) + JWT_EXP_TIME * 60; // 1小时有效期
		return new jose.SignJWT({ sub: userId })
			.setProtectedHeader({ alg: 'HS256' })
			.setExpirationTime(exp)
			.sign(new TextEncoder().encode(secret));
	}


	// 验证密码
	private async verifyPassword(password: string, hash: string): Promise<boolean> {
		// 使用bcrypt验证
		return await bcrypt.compare(password, hash);
	}
}

// 环境变量类型定义
export interface AuthEnv {
	API_SECRET: string;
	JWT_PUBLIC_KEY: string;
	USER_KV: KVNamespace;
	RATE_LIMIT_KV: KVNamespace;
}
