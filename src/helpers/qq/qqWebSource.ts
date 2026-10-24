import CyMusicQqLogin from '../../../modules/cymusic-native/qqLogin'
import { logInfo, logWarn } from '@/helpers/logger'

// Current file: built-in QQ audio source backed by the official web session stored in Keychain.
export const QQ_WEB_SOURCE_ID = 'qq-web-login'
const SOURCE_NAME = 'QQ 音乐（官方登录）'
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/106.0.0.0 Safari/537.36'

const cookieValue = (cookie: string, name: string): string => {
	for (const item of cookie.split(';')) {
		const separator = item.indexOf('=')
		if (separator <= 0) continue
		if (item.slice(0, separator).trim() === name) {
			return item.slice(separator + 1).trim()
		}
	}
	return ''
}

const qqNumber = (cookie: string): string => {
	const value = cookieValue(cookie, 'uin') || cookieValue(cookie, 'p_uin')
	return value.replace(/^o/i, '').replace(/^0+(?=\d)/, '')
}

const fileForQuality = (songmid: string, quality: string): string => {
	const extension = quality === 'flac' ? 'flac' : 'mp3'
	const prefix = quality === 'flac' ? 'F000' : quality === '320k' ? 'M800' : 'M500'
	return `${prefix}${songmid}${songmid}.${extension}`
}

const audioUrlFromAnswer = (body: any, songmid: string): string | null => {
	const data = body?.req_0?.data
	const entry = Array.isArray(data?.midurlinfo)
		? data.midurlinfo.find((item: any) => item?.songmid === songmid) ?? data.midurlinfo[0]
		: null
	const purl = typeof entry?.purl === 'string' ? entry.purl.trim() : ''
	if (!purl) return null
	if (/^https?:\/\//i.test(purl)) return purl
	const sip = Array.isArray(data?.sip)
		? data.sip.find((item: unknown) => typeof item === 'string' && item.startsWith('https://'))
			?? data.sip.find((item: unknown) => typeof item === 'string')
		: null
	if (typeof sip !== 'string' || !sip) return null
	return `${sip.replace(/\/?$/, '/')}${purl.replace(/^\//, '')}`
}

async function getQqWebMusicUrl(
	_songname: string,
	_artist: string,
	songmid: string,
	quality: string,
): Promise<string | null> {
	const cookie = await CyMusicQqLogin.getSession()
	if (!cookie) {
		throw new Error('请先在首页右上角登录 QQ 音乐账号')
	}
	const uin = qqNumber(cookie)
	if (!uin) throw new Error('QQ 登录会话缺少账号信息，请重新登录')

	const requestData = {
		req_0: {
			module: 'vkey.GetVkeyServer',
			method: 'CgiGetVkey',
			param: {
				filename: [fileForQuality(songmid, quality)],
				guid: cookieValue(cookie, 'pgv_pvid') || '10000',
				songmid: [songmid],
				songtype: [0],
				uin,
				loginflag: 1,
				platform: '20',
			},
		},
		comm: {
			uin,
			format: 'json',
			ct: 24,
			cv: 0,
		},
	}
	const controller = new AbortController()
	const timer = setTimeout(() => controller.abort(), 10000)
	try {
		const apiUrl = `https://u.y.qq.com/cgi-bin/musicu.fcg?format=json&data=${encodeURIComponent(JSON.stringify(requestData))}`
		const response = await fetch(apiUrl, {
			method: 'GET',
			headers: {
				Referer: 'https://y.qq.com/',
				'User-Agent': USER_AGENT,
				Cookie: cookie,
			},
			signal: controller.signal,
		})
		if (!response.ok) {
			logWarn('[QQWebSource] request failed:', response.status)
			return null
		}
		const body = await response.json()
		const url = audioUrlFromAnswer(body, songmid)
		if (url) logInfo(`[QQWebSource] resolved ${songmid} at ${quality}`)
		return url
	} finally {
		clearTimeout(timer)
	}
}

export function createQqWebMusicApi(): IMusic.MusicApi {
	return {
		id: QQ_WEB_SOURCE_ID,
		platform: 'tx',
		author: 'CyMusic',
		name: SOURCE_NAME,
		version: '1.0.0',
		srcUrl: '',
		script: '',
		scriptType: 'builtin-qq-web',
		isSelected: false,
		getMusicUrl: getQqWebMusicUrl,
	}
}
