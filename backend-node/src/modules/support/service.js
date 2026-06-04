// Support Module - Business Logic Service

const { getPrisma } = require('../../db/prisma');
const { createLogger } = require('../../shared/logger');

const logger = createLogger('support-service');

async function submitFeedback(userId, data) {
  const prisma = getPrisma();
  const ticket = await prisma.supportTicket.create({
    data: {
      userId,
      category: data.category,
      content: data.content.trim(),
      contact: data.contact || null,
      clientInfo: data.client || null,
    },
  });

  logger.info({ userId, ticketId: ticket.id, category: ticket.category }, 'Support ticket created');

  return {
    ticketId: ticket.id,
    status: ticket.status,
    createdAt: ticket.createdAt,
  };
}

module.exports = {
  submitFeedback,
};
