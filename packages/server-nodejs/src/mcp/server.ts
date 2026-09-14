/**
 * Aboutme MCP Server
 *
 * 提供 AI 工具用于管理 Aboutme 应用中的个人数据
 * 通过 Streamable HTTP transport 挂载到主服务器的 /mcp 端点
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js';

import { AboutmeClient } from './client';
import { getToolDefinitions } from './tools';

/**
 * 创建 MCP Server 实例
 *
 * 无状态 HTTP 模式下每个请求都会创建新实例，因此保持轻量
 */
export function createMcpServer(client: AboutmeClient): Server {
  const server = new Server(
    {
      name: '@hunmer/aboutme-server',
      version: '1.0.3',
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // 注册工具列表处理器
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
      tools: getToolDefinitions(),
    };
  });

  // 注册工具调用处理器
  server.setRequestHandler(CallToolRequestSchema, async (request: any) => {
    const { name, arguments: args } = request.params;

    try {
    switch (name) {
      // ==================== Chat 工具 ====================

      case 'aboutme_chat_getChannels': {
        const result = await client.getChannels(args as { offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_chat_createChannel': {
        const result = await client.createChannel(args as { name: string; description?: string });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_chat_updateChannel': {
        const { id, ...data } = args as { id: string; name?: string; description?: string };
        const result = await client.updateChannel(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_chat_deleteChannel': {
        const { id } = args as { id: string };
        const result = await client.deleteChannel(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_chat_getMessages': {
        const { channelId, ...params } = args as { channelId: string; offset?: number; count?: number };
        const result = await client.getMessages(channelId, params);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_chat_sendMessage': {
        const { channelId, ...data } = args as {
          channelId: string;
          content: string;
          senderId: string;
          senderName: string;
        };
        const result = await client.sendMessage(channelId, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_chat_deleteMessage': {
        const { channelId, messageId } = args as { channelId: string; messageId: string };
        const result = await client.deleteMessage(channelId, messageId);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_chat_searchMessages': {
        const result = await client.searchMessages(args as { field?: string; value: string; channelId?: string; fuzzy?: boolean; offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Notes 工具 ====================

      case 'aboutme_notes_getNotes': {
        const result = await client.getNotes(args as { folderId?: string; offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_notes_createNote': {
        const result = await client.createNote(args as {
          title: string;
          content: string;
          folderId?: string;
          tags?: string[];
        });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_notes_updateNote': {
        const { id, ...data } = args as {
          id: string;
          title?: string;
          content?: string;
          tags?: string[];
        };
        const result = await client.updateNote(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_notes_deleteNote': {
        const { id } = args as { id: string };
        const result = await client.deleteNote(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_notes_searchNotes': {
        const { keyword, ...params } = args as { keyword: string; offset?: number; count?: number };
        const result = await client.searchNotes(keyword, params);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Activity 工具 ====================

      case 'aboutme_activity_getActivities': {
        const result = await client.getActivities(args as { date?: string; offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_activity_createActivity': {
        const result = await client.createActivity(args as {
          startTime: string;
          endTime: string;
          title: string;
          tags?: string[];
          description?: string;
          mood?: number;
        });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_activity_updateActivity': {
        const { id, ...data } = args as {
          id: string;
          startTime?: string;
          endTime?: string;
          title?: string;
          tags?: string[];
          description?: string;
          mood?: number;
          date?: string;
        };
        const result = await client.updateActivity(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_activity_deleteActivity': {
        const { id, date } = args as { id: string; date?: string };
        const result = await client.deleteActivity(id, date);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_activity_getTodayStats': {
        const result = await client.getTodayStats();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Goods 工具 ====================

      case 'aboutme_goods_getWarehouses': {
        const result = await client.getWarehouses(args as { offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_goods_getItems': {
        const result = await client.getItems(args as { warehouseId?: string; offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_goods_createItem': {
        const result = await client.createItem(args as {
          name: string;
          warehouseId: string;
          description?: string;
          quantity?: number;
          category?: string;
          tags?: string[];
        });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_goods_updateItem': {
        const { id, ...data } = args as {
          id: string;
          name?: string;
          description?: string;
          quantity?: number;
          category?: string;
          tags?: string[];
        };
        const result = await client.updateItem(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_goods_deleteItem': {
        const { id, warehouseId } = args as { id: string; warehouseId?: string };
        const result = await client.deleteItem(id, warehouseId);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_goods_searchItems': {
        const { keyword, ...params } = args as { keyword: string; warehouseId?: string };
        const result = await client.searchItems(keyword, params);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Bill 工具 ====================

      case 'aboutme_bill_getAccounts': {
        const result = await client.getAccounts(args as { offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_bill_getBills': {
        const { accountId, ...params } = args as { accountId: string; offset?: number; count?: number };
        const result = await client.getBills(accountId, params);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_bill_createBill': {
        const { accountId, ...data } = args as {
          accountId: string;
          type: 'income' | 'expense' | 'transfer';
          amount: number;
          category?: string;
          description?: string;
          date?: string;
        };
        const result = await client.createBill(accountId, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_bill_updateBill': {
        const { id, ...data } = args as {
          id: string;
          type?: 'income' | 'expense' | 'transfer';
          amount?: number;
          category?: string;
          description?: string;
          date?: string;
        };
        const result = await client.updateBill(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_bill_deleteBill': {
        const { id } = args as { id: string };
        const result = await client.deleteBill(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_bill_getStats': {
        const result = await client.getBillStats(args as { startDate?: string; endDate?: string });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Todo 工具 ====================

      case 'aboutme_todo_getTasks': {
        const result = await client.getTasks(args as {
          completed?: string;
          priority?: string;
          category?: string;
          offset?: number;
          count?: number;
        });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_todo_createTask': {
        const result = await client.createTask(args as {
          title: string;
          description?: string;
          dueDate?: string;
          priority?: number;
          category?: string;
          tags?: string[];
        });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_todo_updateTask': {
        const { id, ...data } = args as {
          id: string;
          title?: string;
          description?: string;
          completed?: boolean;
          dueDate?: string;
          priority?: number;
        };
        const result = await client.updateTask(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_todo_completeTask': {
        const { id } = args as { id: string };
        const result = await client.completeTask(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_todo_getTodayTasks': {
        const result = await client.getTodayTasks();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_todo_getOverdueTasks': {
        const result = await client.getOverdueTasks();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_todo_searchTasks': {
        const { keyword } = args as { keyword: string };
        const result = await client.searchTasks(keyword);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_todo_getStats': {
        const result = await client.getTodoStats();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Diary 工具 ====================

      case 'aboutme_diary_getEntries': {
        const result = await client.getDiaryEntries(args as {
          startDate?: string;
          endDate?: string;
          offset?: number;
          count?: number;
        });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_diary_getEntry': {
        const { date } = args as { date: string };
        const result = await client.getDiaryEntry(date);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_diary_createEntry': {
        const params = args as {
          date: string;
          content: string;
          mood?: number;
          weather?: string;
          tags?: string[];
        };
        // 将 mood 转换为 string 类型
        const diaryData = {
          date: params.date,
          content: params.content,
          mood: params.mood?.toString(),
          weather: params.weather,
          tags: params.tags,
        };
        const result = await client.createDiaryEntry(diaryData);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_diary_updateEntry': {
        const { date, ...data } = args as {
          date: string;
          content?: string;
          mood?: number;
          weather?: string;
          tags?: string[];
        };
        const result = await client.updateDiaryEntry(date, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_diary_deleteEntry': {
        const { date } = args as { date: string };
        const result = await client.deleteDiaryEntry(date);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_diary_searchEntries': {
        const result = await client.searchDiaryEntries(args as {
          keyword?: string;
          startDate?: string;
          endDate?: string;
          mood?: string;
          offset?: number;
          count?: number;
        });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_diary_getStats': {
        const result = await client.getDiaryStats();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Checkin 工具 ====================

      case 'aboutme_checkin_getItems': {
        const result = await client.getCheckinItems(args as { offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_checkin_createItem': {
        const params = args as { name: string; icon?: string | number; color?: string | number; group?: string; description?: string };
        // 转换 icon 和 color 为整数
        const checkinData = {
          name: params.name,
          icon: typeof params.icon === 'string' ? parseInt(params.icon) : (params.icon ?? 57527),
          color: typeof params.color === 'string' ? parseInt(params.color.replace('#', ''), 16) : (params.color ?? 4280391411),
          group: params.group,
          description: params.description,
        };
        const result = await client.createCheckinItem(checkinData);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_checkin_updateItem': {
        const { id, ...data } = args as { id: string; name?: string; icon?: string; color?: string; group?: string; description?: string };
        const result = await client.updateCheckinItem(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_checkin_deleteItem': {
        const { id } = args as { id: string };
        const result = await client.deleteCheckinItem(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_checkin_addRecord': {
        const { itemId, ...data } = args as { itemId: string; date: string; note?: string };
        const result = await client.addCheckinRecord(itemId, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_checkin_getStats': {
        const result = await client.getCheckinStats();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Day 工具 ====================

      case 'aboutme_day_getMemorialDays': {
        const result = await client.getMemorialDays(args as { sortMode?: string; offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_day_createMemorialDay': {
        const params = args as { name: string; date: string; type?: string; description?: string; color?: string };
        // 映射参数并添加默认值
        const memorialDayData = {
          title: params.name,
          targetDate: params.date,
          notes: params.description ? [params.description] : [],
          backgroundColor: params.color ? parseInt(params.color) : 4280391411,
        };
        const result = await client.createMemorialDay(memorialDayData);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_day_updateMemorialDay': {
        const { id, ...data } = args as { id: string; name?: string; date?: string; type?: string; description?: string; color?: string };
        const result = await client.updateMemorialDay(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_day_deleteMemorialDay': {
        const { id } = args as { id: string };
        const result = await client.deleteMemorialDay(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_day_searchMemorialDays': {
        const result = await client.searchMemorialDays(args as { sortMode?: string; startDate?: string; endDate?: string; includeExpired?: boolean });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_day_getStats': {
        const result = await client.getDayStats();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Tracker 工具 ====================

      case 'aboutme_tracker_getGoals': {
        const result = await client.getTrackerGoals(args as { offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_tracker_createGoal': {
        const params = args as { name: string; targetValue: number; unit: string; group?: string; description?: string };
        // 添加必需的默认参数
        const trackerData = {
          name: params.name,
          targetValue: params.targetValue,
          unitType: params.unit,
          icon: '57455', // 默认图标
          iconColor: 4280391411, // 默认颜色
          progressColor: 4280391411, // 默认进度颜色
          dateSettings: { type: 'daily' }, // 默认每日重置
          group: params.group,
          description: params.description,
        };
        const result = await client.createTrackerGoal(trackerData);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_tracker_updateGoal': {
        const { id, ...data } = args as { id: string; name?: string; targetValue?: number; unit?: string; group?: string; description?: string };
        const result = await client.updateTrackerGoal(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_tracker_deleteGoal': {
        const { id } = args as { id: string };
        const result = await client.deleteTrackerGoal(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_tracker_addRecord': {
        const result = await client.addTrackerRecord(args as { goalId: string; value: number; date: string; note?: string });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_tracker_getStats': {
        const result = await client.getTrackerStats();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Contact 工具 ====================

      case 'aboutme_contact_getContacts': {
        const result = await client.getContacts(args as { offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_contact_createContact': {
        const result = await client.createContact(args as { name: string; phone?: string; email?: string; tags?: string[]; notes?: string });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_contact_updateContact': {
        const { id, ...data } = args as { id: string; name?: string; phone?: string; email?: string; tags?: string[]; notes?: string };
        const result = await client.updateContact(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_contact_deleteContact': {
        const { id } = args as { id: string };
        const result = await client.deleteContact(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_contact_searchContacts': {
        const { keyword } = args as { keyword: string };
        const result = await client.searchContacts(keyword);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_contact_getStats': {
        const result = await client.getContactStats();
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      // ==================== Calendar 工具 ====================

      case 'aboutme_calendar_getEvents': {
        const result = await client.getCalendarEvents(args as { startDate?: string; endDate?: string; offset?: number; count?: number });
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_calendar_createEvent': {
        const params = args as { title: string; startTime: string; endTime?: string; description?: string; location?: string; icon?: number; color?: number };
        // 添加默认值
        const eventData = {
          title: params.title,
          startTime: params.startTime,
          endTime: params.endTime,
          description: params.description,
          location: params.location,
          icon: params.icon ?? 58050, // 默认图标
          color: params.color ?? 4280391411, // 默认颜色
        };
        const result = await client.createCalendarEvent(eventData);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_calendar_updateEvent': {
        const { id, ...data } = args as { id: string; title?: string; startTime?: string; endTime?: string; description?: string; location?: string };
        const result = await client.updateCalendarEvent(id, data);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_calendar_deleteEvent': {
        const { id } = args as { id: string };
        const result = await client.deleteCalendarEvent(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_calendar_completeEvent': {
        const { id } = args as { id: string };
        const result = await client.completeCalendarEvent(id);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      case 'aboutme_calendar_searchEvents': {
        const { keyword } = args as { keyword: string };
        const result = await client.searchCalendarEvents(keyword);
        return { content: [{ type: 'text', text: JSON.stringify(result.data, null, 2) }] };
      }

      default:
        throw new Error(`未知工具: ${name}`);
    }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return { content: [{ type: 'text', text: `错误: ${message}` }], isError: true };
    }
  });

  return server;
}
