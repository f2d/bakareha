
//* -------- functions: --------

function is_ie() { return document.all && !document.opera; }
function getAllByMethod(m,v,p) {
	try {
		var a = (p || document)[m](v);
		return Array.prototype.slice.call(a);
	} catch (error) {
		return a || [];
	}
}

function getAllByClass(v,p) { return getAllByMethod('getElementsByClassName',v,p); }
function getAllByTag(v,p) { return getAllByMethod('getElementsByTagName',v,p); }
function getOneById(i) { return document.getElementById(i); }

function toggle_display() {
	for (var style, show, e, a = arguments, i = 0, k = a.length; i < k; i++) {
		var arg = a[i];
		if (
			typeof arg !== 'object'
		&&	typeof arg !== 'string'
		) {
			show = !!arg;
		} else
		if (
			(e = (typeof arg === 'object' ? arg : getOneById(arg)))
		&&	(style = e.style)
		) {
			var show_this = (
				typeof show === 'undefined'
				? style.display === 'none'
				: show
			);
			style.display = 'none'; //* <- needed for initial override
			style.display = (show_this ? '' : 'none');
		}
	}
	return show;
}

function toggle_postform(show, form) {
	if (typeof show === 'undefined') {
		if (!form) form = getOneById('postform');
		if (form) show = !!(
			!form.getAttribute('style')
		||	form.style.display === 'none'
		);
	}

	if (show) {
		toggle_display(false, 'toggle-postform-active');
		toggle_display(true, 'toggle-postform-disabled', form || 'postform');
	} else {
		toggle_display(false, 'toggle-postform-disabled', form || 'postform');
		toggle_display(true, 'toggle-postform-active');
	}
}

function cre(e,p,b) {
	e = document.createElement(e);
	if (b) p.insertBefore(e, b); else
	if (p) p.appendChild(e);
	return e;
}

function reply_insert(text,thread) {
	var postForm = getOneById('postform');
	var replyForm = (typeof thread === 'undefined' ? postForm : getOneById('postform'+thread)) || postForm;
	var textArea = replyForm.comment;

	toggle_postform(true, replyForm);

	if (textArea) {
//* IE:
		if (textArea.createTextRange && (postForm = textArea.caretPos)) {
			postForm.text = (postForm.text.charAt(postForm.text.length-1) === ' ' ? text+' ' : text);
		} else
//* Firefox:
		if (textArea.setSelectionRange) {
			var start = textArea.selectionStart;
			var end = textArea.selectionEnd;
			textArea.value = textArea.value.substr(0,start)+text+textArea.value.substr(end);
			textArea.setSelectionRange(start+text.length,start+text.length);
		} else {
			textArea.value += text+' ';
		}
		if ('activeElement' in document) postForm = document.activeElement; else
		if ('querySelector' in document) postForm = document.querySelector(':focus'); else postForm = null;
		if (replyForm !== postForm) {
			document.body.firstElementChild.scrollIntoView(false);
			textArea.focus();
		}
	}
}

function insert_reply(text,link) {
	if (document.body.className === 'mainpage') document.location = link+hash_prefix+text;
	else reply_insert(text);
}

function size_field(i,rows) {
	getOneById(i).comment.setAttribute('rows',rows);
}

function delete_post(thread,post,file) {
	if (confirm('Are you sure you want to delete reply '+post+'?')) {
		var fileonly = false;
		var script = document.forms[0].action;
		var password = document.forms[0].password.value;
		if (file) fileonly = confirm('Leave the reply text and delete the only file?');

		document.location = (
			script
		+	'?task=delete'
		+	'&delete='+thread+','+post
		+	'&password='+password
		+	'&fileonly='+(fileonly?1:0)
		);
	}
}

function preview_post(formId,thread) {
	var form = getOneById(formId);
	var preview = getOneById('preview'+thread);
	var x = get_xhr();

	if (!(form && preview && x)) {
		return;
	}

	preview.style.display = '';
	preview.innerHTML = '<em>Loading...</em>';

	var url = (
		'?task=preview'
	+	'&comment='+encodeURIComponent(form.comment.value)
	+	'&markup='+encodeURIComponent(form.markup.value)
	);

	if (thread) url += '&thread='+thread;

	x.open('POST', self);
	x.onreadystatechange = function() {
		if (x.readyState === 4) preview.innerHTML = x.responseText;
	}
	if (is_ie() || x.setRequestHeader) x.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
	x.send(url);
}

function get_xhr() {
	try { return new XMLHttpRequest(); } catch (error) {}
	try { return new ActiveXObject('Msxml2.XMLHTTP'); } catch (error) {}
	try { return new ActiveXObject('Microsoft.XMLHTTP'); } catch (error) {}
}

function set_new_inputs(i) {
	if (!(i && (i = getOneById(i)) && i.link)) {
		return;
	}

	var e;
	if ((e = i.field_a) && !e.value) e.value = get_cookie('name');
	if ((e = i.field_b) && !e.value) e.value = get_cookie('link');
	if ((e = i.password) && !e.value) e.value = get_password('password');
	if (e = i.save_useragent) e.checked = !!get_cookie('save_useragent');
	if (e = i.markup) {
		if ((i = i.comment) && !i.value) e.value = get_cookie('markup');
		select_markup(e);
	}
}

function set_delpass(i) {
	with (getOneById(i)) password.value = get_cookie('password');
}

function make_password() {
	var chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
	var pass = '';
	var i = 8;
	var j = chars.length;
	while (i--) pass += chars[Math.floor(Math.random()*j)];
	return pass;
}

function get_password(name) {
	var pass = get_cookie(name);
	if (pass) return pass;
	return make_password();
}

function select_markup(s) {
	if (m = window.markup_descriptions) {
		var m,e = s;
		while (e = e.nextSibling) if (e.nodeName.toLowerCase() === 'small') break;
		if (e) e.innerHTML = m[s.value];
	}
}

function get_cookie(name) {
	with (document.cookie) {
		var regexp = new RegExp('(^|;\\s+)'+name+'=(.*?)(;|$)');
		var hit = regexp.exec(document.cookie);
		return (hit && hit.length > 2) ? unescape(hit[2]) : '';
	}
};

function set_cookie(name,value,days) {
	var x = '';
	if (days) {
		var date = new Date();
		date.setTime(date.getTime()+(days*24*60*60*1000));
		x = '; expires='+date.toGMTString();
	}
	document.cookie = name+'='+value+x+'; path=/';
}

function attrs(e) {
	return e ? {
		'rel' : e.getAttribute('rel')
	,	'title' : e.getAttribute('title')
	} : {};
}

function set_stylesheet(style_title) {
	var att;
	var a = getAllByTag('link');
	var i = a.length;
	var found = false;
	while (i--) if ((att = attrs(a[i])).title && att.rel.indexOf('style') >= 0) {
		a[i].disabled = true; //* <- IE needs this to work.
		if (style_title === att.title) a[i].disabled = !(found = true);
	}
	if (!found) set_preferred_stylesheet();
}

function set_preferred_stylesheet() {
	var att;
	var a = getAllByTag('link');
	var i = a.length;
	while (i--) if ((att = attrs(a[i])).title && att.rel.indexOf('style') >= 0) {
		a[i].disabled = (att.rel.indexOf('alt') >= 0);
	}
}

function get_active_stylesheet() {
	var att;
	var a = getAllByTag('link');
	var i = a.length;
	while (i--) if (!a[i].disabled && (att = attrs(a[i])).title && att.rel.indexOf('style') >= 0) {
		return att.title;
	}
}

function get_preferred_stylesheet() {
	var att;
	var a = getAllByTag('link');
	var i = a.length;
	while (i--) if ((att = attrs(a[i])).title && att.rel.indexOf('style') >= 0 && att.rel.indexOf('alt') < 0) {
		return att.title;
	}
	return null;
}

function on_page_close(e) {
	if (style_cookie) {
		set_cookie(style_cookie, get_active_stylesheet(), 365);
	}
}

function on_page_open(e) {
	if (style_cookie) {
		set_stylesheet(get_cookie(style_cookie) || get_preferred_stylesheet());
	}
	var h = location.hash;
	var a = getAllByClass('abbrev');
	var i = a.length;
	var b,c,e,p,t;
	while (i--) if (
		(e = a[i])
	&&	(p = e.parentNode)
	&&	(t = p.tagName) && t.toLowerCase() === 'p'
	&&	(t = p.parentNode)
	) {
		t.insertBefore(e, p.nextSibling);
	}
	if (getOneById('de-pform')) {
		return;
	}
	if (!getOneById('postform') && (i = getAllByTag('hr')) && (i = i[1])) {
		i.previousElementSibling.innerHTML = postform_fallback;
	}
	var d = document.body;
	var i = getAllByTag('select');
	var o = {
		'postform': set_new_inputs
	,	'delform': set_delpass
	};
	if (d.getAttribute('style')) d.setAttribute('style', '');
	if (i.length) i[0].value = get_active_stylesheet();
	for (var k in o) if (getOneById(k)) o[k](k);

	if (i = getOneById('postform')) {
		if (
			!i.comment.value
		&&	h && h.slice(0, c = hash_prefix.length) === hash_prefix
		&&	(c = h.slice(c))
		) {
			try {
				reply_insert(unescape(c));
			} catch (error) {
				reply_insert(c);
			}
		} else {
			var c = 0;
		}
		var o = {
			'index-form-header' : 'Start a new thread'
		,	'reply-form-header' : 'Write a reply'
		};
		for (var k in o) if (e = getOneById(k)) {
			d = getAllByTag('span',e)[0];
			d.id = 'toggle-postform-disabled';
			d.outerHTML += '<a href="javascript:toggle_postform(true)">'+(d.innerHTML || (d.innerHTML = o[k]))+'</a>';

			e = getAllByTag('a',e)[0];
			e.id = 'toggle-postform-active';

			d = cre('div',getAllByTag('tr',i)[0].lastElementChild);
			d.className = 'postform-close';
			d.innerHTML = '[<a href="javascript:toggle_postform(false)">x</a>]';

			toggle_postform(!!c);

			break;
		}
	}
}

//* -------- runtime: --------

var style_cookie;
var captcha_key = make_password();
var hash_prefix = '#i';
var i = getOneById('postform');
var postform_fallback = (i ? i.innerHTML : '') || (
	'<table><tr><td><ul>'
+	'<li>EN: If post form is not found here, try to disable your extensions/userscripts for this site.</li>'
+	'<li>RU: Если нет формы отправки поста, отключите убравшие её расширения (например Куклоскрипт).</li>'
+	'</ul></td></tr></table>'
);

if (window.addEventListener) {
	window.addEventListener('DOMContentLoaded', on_page_open, false);
	window.addEventListener('unload', on_page_close, false);
} else {
	window.onload = on_page_open;
	window.onunload = on_page_close;
}
